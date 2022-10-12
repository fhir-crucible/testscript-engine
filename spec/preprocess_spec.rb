require_relative '../lib/testscript_engine/testscript_runnable'
require_relative '../lib/testscript_engine/message_handler'

describe TestScriptRunnable do
	before(:all) do
		@script = FHIR.from_contents(File.read('spec/fixtures/basic_testscript.json'))
		@patient = FHIR.from_contents(File.read('spec/fixtures/example_patient.json'))
		@runnable = described_class.new(@script.deep_dup)
		@runnable.client = FHIR::Client.new("https://example.com")
  end

	describe '.preprocess' do
		it 'sends a create request if autocreate_id stored' do
			stub_request(:post, "https://example.com/Patient")
				.to_return(status: 200, body: "", headers: {})

			@runnable.fixtures[@script.fixture.first.id] = @patient
			@runnable.autocreate << @script.fixture.first.id

			@runnable.preprocess
		end

		it 'creates nothing if no autocreates stored' do
			expect(@runnable).to receive(:info).with(:no_preprocess)

			expect(@runnable).not_to receive(:client)

			@runnable.autocreate.clear

			@runnable.preprocess
		end
	end
end