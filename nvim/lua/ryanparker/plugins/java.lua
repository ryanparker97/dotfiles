return {
  {
    "mfussenegger/nvim-jdtls",
    ft = "java",
  },
  require("ryanparker.util.mason").ensure({ "java-debug-adapter", "java-test" }),
}
