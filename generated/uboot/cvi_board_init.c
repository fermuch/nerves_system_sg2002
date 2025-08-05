int cvi_board_init(void)
{
        // WIFI/BT
        PINMUX_CONFIG(AUX0, XGPIOA_30); // BT_REG_ON & WIFI_REG_ON -- gpio510
        PINMUX_CONFIG(JTAG_CPU_TMS, UART1_RTS);
        PINMUX_CONFIG(JTAG_CPU_TCK, UART1_CTS);
        PINMUX_CONFIG(IIC0_SDA, UART1_RX);
        PINMUX_CONFIG(IIC0_SCL, UART1_TX);

        // Camera
        PINMUX_CONFIG(PWR_WAKEUP0, PWR_GPIO_6); // CAM_EN -- gpio358
        PINMUX_CONFIG(PWR_GPIO1, IIC2_SCL); // PWR_GPIO1 -- IIC2_SCL
        PINMUX_CONFIG(PWR_GPIO2, IIC2_SDA); // PWR_GPIO2 -- IIC2_SDA

        // Red & Blue leds
        PINMUX_CONFIG(SPK_EN, XGPIOA_15); // GPIO15/IR_CUT -- gpio495
        PINMUX_CONFIG(GPIO_ZQ, PWR_GPIO_24); // PAD_ZQ -- gpio376
        // White led
        PINMUX_CONFIG(PWR_GPIO0, PWR_GPIO_0); // PWR_GPIO0 -- gpio352

        return 0;
}