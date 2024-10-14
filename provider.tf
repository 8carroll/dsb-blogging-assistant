terraform {
  cloud {
    organization = "TutorialOrgBcrrll"

    workspaces {
      name = "dsb-blogging-assistant"
    }
  }
}

provider "aws" {
  region = "ca-central-1"
}