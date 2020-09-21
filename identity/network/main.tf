data "aws_vpc" "default" {
  default = true
}

data "aws_subnet_ids" "default" {
  vpc_id = data.aws_vpc.default.id
}

data "aws_subnet" "default" {
  count = length(data.aws_subnet_ids.default.ids)
  id    = tolist(data.aws_subnet_ids.default.ids)[count.index]
}

output "vpc_id" {
  value = data.aws_vpc.default.id
}

output "subnet_ids" {
  value = values(zipmap(data.aws_subnet.default.*.availability_zone, data.aws_subnet.default.*.id))
}

output "azs" {
  value = sort(data.aws_subnet.default.*.availability_zone)
}
