#include <iostream>
#include <string>
#include <vector>
#include <chrono>
#include <cstring>
#include <csignal>
#include <forward_list>
#include <cstdio>
#include <cstdlib>
#include <exception>
#include <signal.h>
#include <fstream>
#include <opencv2/opencv.hpp>
#include <sscma.h>
#include <cvi_comm_vb.h>
#include <cvi_vb.h>
#include <cvi_sys.h>
#include <video.h>

#define TAG "TPU_YOLO"

// YOLO class names
const std::vector<std::string> CLASS_NAMES = {
    "person", "bicycle", "car", "motorcycle", "airplane", "bus", "train", "truck", "boat", "traffic light",
    "fire hydrant", "stop sign", "parking meter", "bench", "bird", "cat", "dog", "horse", "sheep", "cow",
    "elephant", "bear", "zebra", "giraffe", "backpack", "umbrella", "handbag", "tie", "suitcase", "frisbee",
    "skis", "snowboard", "sports ball", "kite", "baseball bat", "baseball glove", "skateboard", "surfboard",
    "tennis racket", "bottle", "wine glass", "cup", "fork", "knife", "spoon", "bowl", "banana", "apple",
    "sandwich", "orange", "broccoli", "carrot", "hot dog", "pizza", "donut", "cake", "chair", "couch",
    "potted plant", "bed", "dining table", "toilet", "tv", "laptop", "mouse", "remote", "keyboard", "cell phone",
    "microwave", "oven", "toaster", "sink", "refrigerator", "book", "clock", "vase", "scissors", "teddy bear",
    "hair drier", "toothbrush"
};

// Base64 encoding
std::string base64_encode(const unsigned char* data, size_t len) {
    static const char* b64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    std::string ret;
    ret.reserve((len + 2) / 3 * 4);

    for (size_t i = 0; i < len; i += 3) {
        int b = (data[i] & 0xFC) >> 2;
        ret.push_back(b64[b]);
        b = (data[i] & 0x03) << 4;
        if (i + 1 < len) {
            b |= (data[i + 1] & 0xF0) >> 4;
            ret.push_back(b64[b]);
            b = (data[i + 1] & 0x0F) << 2;
            if (i + 2 < len) {
                b |= (data[i + 2] & 0xC0) >> 6;
                ret.push_back(b64[b]);
                b = data[i + 2] & 0x3F;
                ret.push_back(b64[b]);
            } else {
                ret.push_back(b64[b]);
                ret.push_back('=');
            }
        } else {
            ret.push_back(b64[b]);
            ret.push_back('=');
            ret.push_back('=');
        }
    }

    return ret;
}

// Preprocess image following original example
cv::Mat preprocessImage(cv::Mat& image, ma::Model* model) {
    int ih = image.rows;
    int iw = image.cols;
    int oh = 640;  // Default YOLO size
    int ow = 640;

    if (model->getInputType() == MA_INPUT_TYPE_IMAGE) {
        oh = reinterpret_cast<const ma_img_t*>(model->getInput())->height;
        ow = reinterpret_cast<const ma_img_t*>(model->getInput())->width;
    }

    cv::Mat resizedImage;
    double resize_scale = std::min((double)oh / ih, (double)ow / iw);
    int nh = (int)(ih * resize_scale);
    int nw = (int)(iw * resize_scale);
    cv::resize(image, resizedImage, cv::Size(nw, nh));

    int top = (oh - nh) / 2;
    int bottom = (oh - nh) - top;
    int left = (ow - nw) / 2;
    int right = (ow - nw) - left;

    cv::Mat paddedImage;
    cv::copyMakeBorder(resizedImage, paddedImage, top, bottom, left, right, cv::BORDER_CONSTANT, cv::Scalar::all(0));
    cv::cvtColor(paddedImage, paddedImage, cv::COLOR_BGR2RGB);

    return paddedImage;
}

// Initialize camera following the pattern from the original example
ma::Camera* initialize_camera() {
    MA_LOGI(TAG, "Initializing camera...");
    std::cout << "[dbg] initialize_camera: get device instance" << std::endl;

    // Get device instance and find camera sensor
    ma::Device* device = ma::Device::getInstance();
    ma::Camera* camera = nullptr;

    std::cout << "[dbg] initialize_camera: scanning sensors" << std::endl;
    for (auto& sensor : device->getSensors()) {
        if (sensor->getType() == ma::Sensor::Type::kCamera) {
            camera = static_cast<ma::Camera*>(sensor);
            break;
        }
    }

    if (!camera) {
        MA_LOGE(TAG, "No camera sensor found");
        return nullptr;
    }

    // Initialize camera
    std::cout << "[dbg] initialize_camera: calling camera->init(0)" << std::endl;
    if (camera->init(0) != MA_OK) {
        MA_LOGE(TAG, "Camera initialization failed");
        return nullptr;
    }

    // Configure camera
    ma::Camera::CtrlValue value;

    // Set channel
    value.i32 = 0;
    std::cout << "[dbg] initialize_camera: set channel" << std::endl;
    if (camera->commandCtrl(ma::Camera::CtrlType::kChannel, ma::Camera::CtrlMode::kWrite, value) != MA_OK) {
        MA_LOGE(TAG, "Failed to set camera channel");
        return nullptr;
    }

    // Set resolution
    value.u16s[0] = 1920;
    value.u16s[1] = 1080;
    std::cout << "[dbg] initialize_camera: set window 1920x1080" << std::endl;
    if (camera->commandCtrl(ma::Camera::CtrlType::kWindow, ma::Camera::CtrlMode::kWrite, value) != MA_OK) {
        MA_LOGE(TAG, "Failed to set camera resolution");
        return nullptr;
    }

    // Set FPS
    value.i32 = 5;
    std::cout << "[dbg] initialize_camera: set fps 5" << std::endl;
    camera->commandCtrl(ma::Camera::CtrlType::kFps, ma::Camera::CtrlMode::kWrite, value);

    // Start camera stream
    std::cout << "[dbg] initialize_camera: startStream" << std::endl;
    camera->startStream(ma::Camera::StreamMode::kRefreshOnReturn);

    MA_LOGI(TAG, "Camera initialized successfully");
    std::cout << "[dbg] initialize_camera: success" << std::endl;
    return camera;
}

// Initialize model following the pattern from the original example
ma::Model* initialize_model(const std::string& model_path) {
    ma_err_t ret = MA_OK;

    MA_LOGI(TAG, "Initializing TPU engine...");
    std::cout << "[dbg] initialize_model: creating engine" << std::endl;
    auto* engine = new ma::engine::EngineCVI();
    std::cout << "[dbg] initialize_model: engine created" << std::endl;
    ret = engine->init();
    std::cout << "[dbg] initialize_model: engine->init ret=" << ret << std::endl;
    if (ret != MA_OK) {
        MA_LOGE(TAG, "Engine init failed");
        delete engine;
        return nullptr;
    }

    MA_LOGI(TAG, "Loading model: %s", model_path.c_str());
    std::cout << "[dbg] initialize_model: loading model" << std::endl;
    ret = engine->load(model_path);
    std::cout << "[dbg] initialize_model: engine->load ret=" << ret << std::endl;
    if (ret != MA_OK) {
        MA_LOGE(TAG, "Engine load model failed");
        delete engine;
        return nullptr;
    }

    std::cout << "[dbg] initialize_model: creating Model via factory" << std::endl;
    ma::Model* model = ma::ModelFactory::create(engine);
    std::cout << "[dbg] initialize_model: ModelFactory::create done" << std::endl;
    if (model == nullptr) {
        MA_LOGE(TAG, "Model not supported");
        delete engine;
        return nullptr;
    }

    MA_LOGI(TAG, "Model initialized, type: %d", model->getType());
    return model;
}

static void crash_signal_handler(int sig) {
    const char* name = "unknown";
    switch (sig) {
        case SIGSEGV: name = "SIGSEGV"; break;
        case SIGABRT: name = "SIGABRT"; break;
        case SIGFPE:  name = "SIGFPE";  break;
        case SIGILL:  name = "SIGILL";  break;
        case SIGBUS:  name = "SIGBUS";  break;
        default: break;
    }
    fprintf(stderr, "[fatal] Caught signal %s (%d)\n", name, sig);
    fflush(stderr);
    _Exit(128 + sig);
}

// static void install_crash_handlers() {
//     signal(SIGSEGV, crash_signal_handler);
//     signal(SIGABRT, crash_signal_handler);
//     signal(SIGFPE,  crash_signal_handler);
//     signal(SIGILL,  crash_signal_handler);
//     signal(SIGBUS,  crash_signal_handler);
//     std::set_terminate([](){
//         const std::exception_ptr p = std::current_exception();
//         if (p) {
//             try { std::rethrow_exception(p); }
//             catch (const std::exception& e) {
//                 fprintf(stderr, "[fatal] Uncaught exception: %s\n", e.what());
//             }
//             catch (...) {
//                 fprintf(stderr, "[fatal] Uncaught non-standard exception\n");
//             }
//         } else {
//             fprintf(stderr, "[fatal] std::terminate without active exception\n");
//         }
//         fflush(stderr);
//         _Exit(1);
//     });
// }

int main() {
    using namespace ma;

    Device* device = Device::getInstance();
    Camera* camera = nullptr;

    Signal::install({SIGINT, SIGSEGV, SIGABRT, SIGTRAP, SIGTERM, SIGHUP, SIGQUIT, SIGPIPE}, [device](int sig) {
        std::cout << "Caught signal " << sig << std::endl;
        for (auto& sensor : device->getSensors()) {
            sensor->deInit();
        }
        exit(0);
    });

    for (auto& sensor : device->getSensors()) {
        // debug the sensor type
        std::cout << "[dbg] sensor type: " << Sensor::__repr__(sensor->getType()) << std::endl;
    }

    // // Cleanup
    // camera->stopStream();
    // // Stop video pipeline
    // CVI_SYS_Exit();
    // CVI_VB_Exit();
    // ma::ModelFactory::remove(model);

    MA_LOGI(TAG, "Done!");
    return 0;
}
