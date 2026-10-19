module "karpenter" {
  source  = "terraform-aws-modules/eks/aws//modules/karpenter"
  version = "21.29.0"

  cluster_name = module.eks.cluster_name

  # Pod Identity association for kube-system/karpenter (module default).
  create_pod_identity_association = true

  iam_role_name            = "${var.cluster_name}-karpenter-controller"
  iam_role_use_name_prefix = false

  node_iam_role_name            = "${var.cluster_name}-karpenter-node"
  node_iam_role_use_name_prefix = false
  node_iam_role_additional_policies = {
    AmazonSSMManagedInstanceCore = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  }

  queue_name = "${var.cluster_name}-karpenter-interruptions"
}
