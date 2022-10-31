require_relative '../lib/testscript_engine/testscript_runnable'
require_relative '../lib/testscript_engine/output/message_handler'

describe TestScriptRunnable do
	before(:all) do
		@script = FHIR.from_contents(File.read('spec/examples/basic_testscript.json'))
		@patient = FHIR.from_contents(File.read('spec/examples/example_patient.json'))
		@runnable = described_class.new(@script.deep_dup, lambda { |k| {}[k] })
	end

	before(:each) { @reference = @script.fixture.first.resource.deep_dup }

	describe '.get_fixture_from_ref' do
		it 'given bad reference logs warning' do
			expect(@runnable).to receive(:warning).with(:bad_reference)

			result = @runnable.get_fixture_from_ref(nil)

			expect(result).to be(nil)
		end

		it 'given reference without reference element logs warning' do
			@reference.reference = nil

			expect(@runnable).to receive(:warning).with(:no_reference)

			result = @runnable.get_fixture_from_ref(@reference)

			expect(result).to be(nil)
		end

		it 'given remote reference logs warning' do
			@reference.reference = 'http'

			expect(@runnable).to receive(:warning).with(:unsupported_ref, 'http')

			result = @runnable.get_fixture_from_ref(@reference)

			expect(result).to be(nil)
		end

		context 'given contained resource reference' do
			it 'logs warning if no contained resource' do
				@reference.reference = '#'

				expect(@runnable).to receive(:warning).with(:no_contained_resource, '#')

				result = @runnable.get_fixture_from_ref(@reference)

				expect(result).to be(nil)
			end

			it 'returns contained resource' do
				@runnable.script.contained << @patient
				@reference.reference = "##{@patient.id}"

				result = @runnable.get_fixture_from_ref(@reference)

				expect(result).to be(@patient)
			end
		end

		it 'given bad local reference logs warqning' do
			expect(@runnable).to receive(:warning)
				.with(:missed_fixture, "Patient/example.json")

			result = @runnable.get_fixture_from_ref(@reference)

			expect(result).to be(nil)
		end

		it 'given good local reference logs and returns resource' do
			expect(@runnable).to receive(:info)
				.with(:added_fixture, "examples/example_patient.json")

			@runnable.instance_variable_set(:@get_fixture_block, lambda { |k| { "examples/example_patient.json" => @patient }[k] } )
			@reference.reference = "examples/example_patient.json"
			result = @runnable.get_fixture_from_ref(@reference)

			expect(result).to be
			expect(result.resourceType).to eq("Patient")
		end
	end
end