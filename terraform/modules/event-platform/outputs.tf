output "event_bus_name" {
  description = "Name of the shared event bus. Hand this value to the product teams."
  value       = aws_cloudwatch_event_bus.this.name
}

output "event_bus_arn" {
  description = "ARN of the shared event bus. Hand this value to the product teams."
  value       = aws_cloudwatch_event_bus.this.arn
}
