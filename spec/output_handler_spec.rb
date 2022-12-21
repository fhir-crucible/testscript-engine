require_relative '../lib/testscript_engine/message_handler'

class OutputHandlerTestClass
  include MessageHandler
end

describe MessageHandler do
  before(:all) do
    @message_dict = { "type_one" => "message_one", "type_two" => "message_two" }
    @output_handler = OutputHandlerTestClass.new
    @config_with_dict = { "dictionary" => @message_dict }
    @config_without_dict = { "not_dictionary" => "not_message_dict" }
  end

  describe '.config' do
    before(:each) { @output_handler.instance_variable_set(:@config, nil) }

    context 'without valid path to config file' do
      before { allow(Dir).to receive(:pwd).and_return("gibberish") }

      it 'returns {}' do
        result = @output_handler.config

        expect(result).to eq({})
      end
    end

    context 'with valid path to invalid config file' do
      before { allow(File).to receive(:read).and_return("{:.more_giberish/.${") }

      it 'returns hash' do
        result = @output_handler.config

        expect(result).to eq({})
      end
    end

    context 'with valid path to empty config file' do
      before { allow(File).to receive(:read).and_return("") }

      it 'returns hash' do
        result = @output_handler.config

        expect(result).to eq({})
      end
    end
    
  end

  describe '.message_dictionary' do
    before(:each) { @output_handler.instance_variable_set(:@message_dictionary, nil) }

    context 'with config containing dict' do
      before { @output_handler.instance_variable_set(:@config, @config_with_dict) }

      it 'returns dictionary' do
        result = @output_handler.message_dictionary

        expect(result).to eq(@message_dict)
      end
    end

    context 'with config not containing dict' do
      before { @output_handler.instance_variable_set(:@config, @config_without_dict) }

      it 'returns {}' do
        result = @output_handler.message_dictionary

        expect(result).to eq({})
      end
    end

    context 'without config' do
      before { @output_handler.instance_variable_set(:@config, {}) }

      it 'returns {}' do
        result = @output_handler.message_dictionary

        expect(result).to eq({})
      end
    end
  end
end