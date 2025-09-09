resource "aws_iam_role" "node_group_role" {
  name = "${var.cluster_name}-nodegroup-role"
  assume_role_policy = data.aws_iam_policy_document.nodegroup_assume_role.json
}

data "aws_iam_policy_document" "nodegroup_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "worker_node_ec2" {
  role       = aws_iam_role.node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}
resource "aws_iam_role_policy_attachment" "cni_policy" {
  role       = aws_iam_role.node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}
resource "aws_iam_role_policy_attachment" "registry_policy" {
  role       = aws_iam_role.node_group_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_eks_node_group" "default_nodes" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.cluster_name}-ng"
  node_role_arn   = aws_iam_role.node_group_role.arn
  subnet_ids      = aws_subnet.public[*].id

  scaling_config {
    desired_size = var.node_group_min
    min_size     = var.node_group_min
    max_size     = var.node_group_max
  }

  instance_types = [var.node_instance_type]

  remote_access {
    ec2_ssh_key = "" # optionally set
  }

  tags = {
    Name = "${var.cluster_name}-node"
  }
}