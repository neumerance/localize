require 'rails_helper'

describe StaleObjHandler do

  context '#retry' do
    let(:m) { create :money_account }

    it 'should retry if staled object is raised' do
      m.lock_version = 999

      expect(m).to receive(:reload).once.and_call_original

      attempt_counter = 0
      StaleObjHandler.retry do
        m.hold_sum = (attempt_counter += 1)
        m.save
      end

      expect(attempt_counter).to eq(2)
      expect(m.hold_sum).to eq(attempt_counter)
    end

    # This spec tests how ruby code works. Its just to confirm how blocks works
    it 'should return returned value, access method variables
     and exit from the method where is executed.' do

      def test_method
        ext = 123
        StaleObjHandler.retry do
          return :right_value if ext == 123
          :bad_value
        end
        raise "Shouldn't be raised as return should exit the method where is defined"
      end

      expect(test_method).to eq(:right_value)
    end

    it 'should retry only 5 times' do
      attempt_counter = 0

      expect(m).to receive(:reload).exactly(4).times.and_call_original

      expect do
        StaleObjHandler.retry do
          m.lock_version = 10
          m.hold_sum = (attempt_counter += 1)
          m.save
        end
      end.to raise_error ActiveRecord::StaleObjectError
      expect(attempt_counter).to eq(5)
    end
  end
end
