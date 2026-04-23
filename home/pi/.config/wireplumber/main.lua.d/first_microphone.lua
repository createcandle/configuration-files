rule = {
    matches = {
        {
            { "node.name", "matches", "~alsa_input.usb*" },
        },
    },
    apply_properties = {
        ["node.target"] = "first_available_usb_microphone",
    },
}
