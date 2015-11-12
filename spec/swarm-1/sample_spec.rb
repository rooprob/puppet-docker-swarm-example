require 'spec_helper'

describe 'server' do
  it_behaves_like 'docker'
  it_behaves_like 'consul'
  it_behaves_like 'cluster-primary'
end
