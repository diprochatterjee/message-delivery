output "base_url" {
  value = "${aws_api_gateway_deployment.message_delivery.invoke_url}"
}

output "api_key" {
  value = "${aws_api_gateway_api_key.message_delivery_key.value}"
}
