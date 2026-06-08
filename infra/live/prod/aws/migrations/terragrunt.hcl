include "root" {
  path = find_in_parent_folders("root.hcl")
}

dependency "security" {
  config_path = "${get_original_terragrunt_dir()}/../security"

  mock_outputs = {
    ecs_sg     = "sg-00000000000000004"
    runtime_sg = "sg-00000000000000005"
  }

  mock_outputs_merge_strategy_with_state  = "shallow"
  mock_outputs_allowed_terraform_commands = ["validate", "plan", "destroy", "init", "show", "graph-dependencies", "output-module-groups"]
}

terraform {
  source = "../../../../modules//aws//migrations"
}

inputs = {
  runtime_security_group_id = dependency.security.outputs.runtime_sg
}
