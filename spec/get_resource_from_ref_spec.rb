require_relative '../lib/testscript_runnable'
require_relative '../lib/message_handler'

describe TestScriptRunnable do
	before(:all) do
    @script = FHIR.from_contents(File.read('spec/fixtures/basic_testscript.json'))
    @patient = FHIR.from_contents(File.read('spec/fixtures/example_patient.json'))
    @runnable = described_class.new(@script.deep_dup)
  end

	before(:each) { @reference = @script.fixture.first.resource.deep_dup }

	describe '.get_resource_from_ref' do
		it 'given bad reference logs warning' do
			expect(@runnable).to receive(:warning).with(:bad_reference)

			result = @runnable.get_resource_from_ref(nil)

			expect(result).to be(nil)
		end

		it 'given reference without reference element logs warning' do
			@reference.reference = nil

			expect(@runnable).to receive(:warning).with(:no_reference)

			result = @runnable.get_resource_from_ref(@reference)

			expect(result).to be(nil)
		end

		it 'given remote reference logs warning' do
			@reference.reference = 'http'

			expect(@runnable).to receive(:warning).with(:unsupported_ref, 'http')

			result = @runnable.get_resource_from_ref(@reference)

			expect(result).to be(nil)
		end

		context 'given contained resource reference' do
			it 'logs warning if no contained resource' do
				@reference.reference = '#'

				expect(@runnable).to receive(:warning).with(:no_contained_resource, '#')

				result = @runnable.get_resource_from_ref(@reference)

				expect(result).to be(nil)
			end

			it 'returns contained resource' do
				@runnable.script.contained << @patient
				@reference.reference = "##{@patient.id}"

				result = @runnable.get_resource_from_ref(@reference)

				expect(result).to be(@patient)
			end
		end

		it 'given bad local reference logs warqning' do
			expect(@runnable).to receive(:warning)
				.with(:resource_extraction, @reference.reference, /No such file or directory/)

			result = @runnable.get_resource_from_ref(@reference)

			expect(result).to be(nil)
		end

		it 'given good local reference logs and returns resource' do
			expect(@runnable).to receive(:info)
				.with(:loaded_static_fixture, @patient.id)

			@runnable.script.url = "spec/basic_testscript"
			@reference.reference = "example_patient.json"
			result = @runnable.get_resource_from_ref(@reference)

			expect(result).to be
			expect(result.resourceType).to eq("Patient")
		end
	end
end