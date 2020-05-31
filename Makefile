SERVICE_REGIONS_PATH := ${PWD}/service-regions

################################################################################
# aws コマンドで --profile PROFILE で利用する一覧表示（ないならdefaultが入る）
################################################################################
define profiles
	cat profiles
endef
.PHONY: profiles
profiles:
	$(call profiles) || echo default > profiles

################################################################################
# profileの疎通確認
################################################################################
# $(1)：profile名
define sts-check
	aws sts get-caller-identity --profile $(1)
endef
.PHONY: check
check: profiles
	$(call profiles) | xargs -I {profile} bash -c "echo ===[{profile}] && $(call sts-check,{profile})"

################################################################################
# IAM User一覧
################################################################################
# $(1)：profile名
define iam-users
	export AWS_PAGER='' \
		&& aws iam list-users --query 'Users[].UserName' --profile $(1) \
			| jq --raw-output '.[]'
endef
.PHONY: iam-users
iam-users: profiles
	$(call profiles) | xargs -I {profile} bash -c "echo ===[{profile}] && $(call iam-users,{profile})"

################################################################################
# IAM Role一覧
################################################################################
# $(1)：profile名
define iam-roles
	export AWS_PAGER='' \
		&& aws iam list-roles --query 'Roles[].RoleName' --profile $(1) \
			| jq --raw-output '.[]'
endef
.PHONY: iam-roles
iam-roles: profiles
	$(call profiles) | xargs -I {profile} bash -c "echo ===[{profile}] && $(call iam-roles,{profile})"

################################################################################
# EC2 region一覧（テキストに吐き出す（もし不要な部分があれば、自分で削っていく））
################################################################################
define ec2-regions
	cat ${SERVICE_REGIONS_PATH}/ec2-regions
endef
ec2-regions: profiles
	$(call ec2-regions) \
		|| ( \
			aws ec2 describe-regions --query 'Regions[*].RegionName[]' \
				| jq --raw-output '.[]' > ${SERVICE_REGIONS_PATH}/ec2-regions.all \
				&& cp ${SERVICE_REGIONS_PATH}/ec2-regions.all ${SERVICE_REGIONS_PATH}/ec2-regions \
		)

################################################################################
# VPC一覧
################################################################################
# $(1)：profile名
# $(2)：region名
define vpc-list
	export AWS_PAGER='' \
		&& aws ec2 describe-vpcs --query 'Vpcs[].{CidrBlock: CidrBlock, Tags: Tags[0]}' --profile $(1) --region $(2) \
			| jq --raw-output --compact-output '.[]'
endef
.PHONY: vpc-list
vpc-list: profiles ec2-regions
	$(call profiles) | xargs -I {profile} bash -c "$(call ec2-regions) | xargs -I {region} bash -c \"echo ===[{profile}][{region}] && $(call vpc-list,{profile},{region})\""

################################################################################
# VPC Subnet一覧
################################################################################
# $(1)：profile名
# $(2)：region名
define vpc-subnet-list
	export AWS_PAGER='' \
		&& aws ec2 describe-subnets --query 'Subnets[].{VpcId: VpcId, CidrBlock: CidrBlock}' --profile $(1) --region $(2) \
			| jq --raw-output --compact-output '.[]'
endef
.PHONY: vpc-subnet-list
vpc-subnet-list: profiles ec2-regions
	$(call profiles) | xargs -I {profile} bash -c "$(call ec2-regions) | xargs -I {region} bash -c \"echo ===[{profile}][{region}] && $(call vpc-subnet-list,{profile},{region})\""

################################################################################
# EC2 一覧
################################################################################
# $(1)：profile名
# $(2)：region名
define ec2-list
	export AWS_PAGER='' \
		&& aws ec2 describe-instances --query 'Reservations[].Instances[].{InstanceType: InstanceType, PublicIp: PublicIpAddress, Tags: Tags}' --profile $(1) --region $(2) \
			| jq --raw-output --compact-output '.[]'
endef
.PHONY: ec2-list
ec2-list: profiles ec2-regions
	$(call profiles) | xargs -I {profile} bash -c "$(call ec2-regions) | xargs -I {region} bash -c \"echo ===[{profile}][{region}] && $(call ec2-list,{profile},{region})\""

################################################################################
# S3 一覧
################################################################################
# $(1)：profile名
define s3-list
	export AWS_PAGER="" \
		&& aws s3 ls --profile $(1)
endef
.PHONY: s3-list
s3-list: profiles
	$(call profiles) | xargs -I {profile} bash -c "echo ===[{profile}] && $(call s3-list,{profile})"

.PHONY: clean
clean:
	rm service-regions/*-regions
