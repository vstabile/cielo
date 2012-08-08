#encoding: utf-8
require 'active_support/core_ext/class/attribute_accessors'
require 'active_support/core_ext/module/attribute_accessors'
require 'active_support/core_ext/hash'
require "net/http"
require "rexml/document"
require "builder"
[:connection, :transaction, :status].each { |lib| require "cielo/#{lib}" }

module Cielo

  class Production
    BASE_URL = "ecommerce.cbmp.com.br"
    WS_PATH = "/servicos/ecommwsec.do"
  end

  class Test
    BASE_URL = "qasecommerce.cielo.com.br"
    WS_PATH = "/servicos/ecommwsec.do"
  end
  
  @@environment = :test
  mattr_accessor :environment
  @@numero_afiliacao = '1006993069' #"1001734898"
  mattr_accessor :numero_afiliacao
  @@chave_acesso = '25fbb99741c739dd84d7b06ec78c9bac718838630f30b112d033ce2e621b34f3' #"e84827130b9837473681c2787007da5914d6359947015a5cdb2b8843db0fa832"
  mattr_accessor :chave_acesso
  @@return_path = "http://localhost:3000"
  mattr_accessor :return_path

  def self.setup
    yield self
  end
  class MissingArgumentError < StandardError; end
end