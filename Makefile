.PHONY: check bootstrap validate-migrations expire-content expire-content-dry-run push-delivery push-delivery-dry-run

check:
	./scripts/validate-foundation.sh

bootstrap:
	./scripts/bootstrap-local.sh

validate-migrations:
	./scripts/validate-migrations-postgres.sh

expire-content:
	./scripts/run-expire-content.sh

expire-content-dry-run:
	EXPIRE_DRY_RUN=true ./scripts/run-expire-content.sh

push-delivery:
	./scripts/run-send-push-notifications.sh

push-delivery-dry-run:
	PUSH_DELIVERY_DRY_RUN=true ./scripts/run-send-push-notifications.sh
