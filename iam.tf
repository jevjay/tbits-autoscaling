data "aws_iam_policy_document" "asg" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "asg" {
  for_each = try({ for p in local.instance_profile_config : p.group_name => p }, {})

  name = each.value.name # Details: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role#name

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  assume_role_policy = data.aws_iam_policy_document.asg.json # Details: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role#assume_role_policy

  tags = local.common_tags # Details: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role#tags
}

resource "aws_iam_role_policy" "asg" {
  for_each = try({ for p in local.instance_profile_config : p.group_name => p }, {})

  name = "${each.value.name}_policy"   # Details: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy#name
  role = aws_iam_role.asg[each.key].id # Details: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy#role

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = file("${path.module}/${each.value.policy_json}") # Details: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy#policy
}

resource "aws_iam_instance_profile" "asg" {
  for_each = try({ for p in local.instance_profile_config : p.group_name => p }, {})

  name = each.value.name                 # Details: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_instance_profile#name
  role = aws_iam_role.asg[each.key].name # Details: https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_instance_profile#role
}
