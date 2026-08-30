moved {
  from = aws_iam_role.receiver_deploy
  to   = aws_iam_role.fulfillment_deploy
}

moved {
  from = aws_iam_role_policy_attachment.receiver_deploy
  to   = aws_iam_role_policy_attachment.fulfillment_deploy
}
