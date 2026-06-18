-- Extend yaml-language-server with GitLab CI schema for pipeline template files.
-- The LazyVim YAML extra + SchemaStore already covers `.gitlab-ci.yml` by name,
-- but included templates in subdirectories need explicit mappings.
return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        yamlls = {
          settings = {
            yaml = {
              customTags = {
                "!reference sequence",
                "!reference scalar",
              },
              schemas = {
                ["https://gitlab.com/gitlab-org/gitlab/-/raw/master/app/assets/javascripts/editor/schema/ci.json"] = {
                  ".gitlab-ci.yml",
                  ".gitlab-ci/**/*.yml",
                  ".gitlab/ci/**/*.yml",
                  "ci/**/*.yml",
                },
              },
            },
          },
        },
      },
    },
  },
}
