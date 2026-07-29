require_relative 'lib/aspace_serializer_overrides'
require_relative 'lib/si_ead_extras_serialize'
require_relative 'lib/si_export_helpers'

# Register our custom serialize steps.
EADSerializer.add_serialize_step(SIEADSerialize)
