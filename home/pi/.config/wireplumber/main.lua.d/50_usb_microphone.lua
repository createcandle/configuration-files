rule = {
  matches = {
    {
      { "node.name", "matches", "~alsa_input.usb*" },
    },
  },
  apply_properties = {
      ["node.description"]       = "USB Microphone",
	  [“session.suspend-timeout-seconds”] = 0
  },
}
table.insert(alsa_monitor.rules,rule)
