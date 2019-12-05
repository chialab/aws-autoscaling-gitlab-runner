.PHONY: list-instance-types list-latest-amis test

test:
	@for template in $$(ls *.yml); do \
		aws cloudformation validate-template --template-body file://$$template; \
	done

list-instance-types:
	@instance_types=$$( \
		aws pricing get-attribute-values \
			--service-code AmazonEC2 \
			--attribute-name instanceType \
			--region us-east-1 \
			--query 'AttributeValues[].Value' \
			--output text \
	); \
	for instance_type in $$instance_types; do \
		printf ' - '\''%s'\''\n' $$instance_type; \
	done

list-latest-amis:
	@for region in $$(aws ec2 describe-regions --query 'Regions[].RegionName' --output text); do \
		ami_id=$$( \
			aws ec2 describe-images \
				--owners amazon \
				--filters 'Name=name,Values=amzn2-ami-hvm-*-gp2' \
					'Name=image-type,Values=machine' \
					'Name=virtualization-type,Values=hvm' \
					'Name=architecture,Values=x86_64' \
				--region $$region \
				--query 'reverse(sort_by(Images, &CreationDate))[0].ImageId' \
				--output text \
		); \
		printf '%s:\n  %s: '\''%s'\''\n' $$region 'AmiId' $$ami_id; \
	done
