# Producers register here. Adding one is a one-line pull request.
# This cannot be split into per-team stacks: there is one bus resource policy
# and it is last-write-wins.

locals {
  producers = {
    "order-service" = {
      account_id = "111111111111"
    }
  }
}
