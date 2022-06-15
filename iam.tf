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

  name = each.value.name

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  assume_role_policy = data.aws_iam_policy_document.asg.json

  tags = local.common_tags
}

resource "aws_iam_role_policy" "asg" {
  for_each = try({ for p in local.instance_profile_config : p.group_name => p }, {})

  name = "${each.value.name}_policy"
  role = aws_iam_role.asg[each.key].id

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = file("${path.module}/${each.value.policy_json}")
}

resource "aws_iam_instance_profile" "asg" {
  for_each = try({ for p in local.instance_profile_config : p.group_name => p }, {})

  name = each.value.name
  role = aws_iam_role.asg[each.key].name
}
