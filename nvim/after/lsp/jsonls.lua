local ok_schema, schemastore = pcall(require, "schemastore")

return {
  settings = {
    json = {
      schemas = ok_schema and schemastore.json.schemas() or nil,
      validate = { enable = true },
    },
  },
}
