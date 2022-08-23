# frozen_string_literal: true

RSpec.describe Rails::Transactional::Outbox do
  it "has a version number" do
    expect(Rails::Transactional::Outbox::VERSION).not_to be nil
  end

  it "does something useful" do
    expect(false).to eq(true)
  end
end
