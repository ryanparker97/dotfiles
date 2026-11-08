local ok_schema, schemastore = pcall(require, "schemastore")

return {
  filetypes = { "yaml", "yaml.docker-compose", "yaml.gitlab", "yaml.helm-values", "yaml.cloudformation" },
  settings = {
    yaml = {
      schemaStore = { enable = false, url = "" },
      schemas = ok_schema and schemastore.yaml.schemas() or {},
      validate = true,
      completion = true,
      hover = true,
      customTags = {
        "!And sequence",
        "!If sequence",
        "!Not sequence",
        "!Equals sequence",
        "!Or sequence",
        "!FindInMap sequence",
        "!Base64 scalar",
        "!Cidr sequence",
        "!Ref scalar",
        "!Sub scalar",
        "!Sub sequence",
        "!GetAtt scalar",
        "!GetAtt sequence",
        "!GetAZs scalar",
        "!ImportValue scalar",
        "!ImportValue sequence",
        "!Select sequence",
        "!Split sequence",
        "!Join sequence",
      },
    },
  },
}
