#encoding: utf-8
module Cielo
  class Transaction
    def initialize
      @connection = Cielo::Connection.new
    end

    def criacao!(parameters={})
      valida_criacao parameters
      message = xml_builder("requisicao-transacao") do |xml|
        xml.tag!("dados-portador") do
          xml.tag!("numero", parameters[:numero].to_s)
          xml.tag!("validade", parameters[:validade].to_s)
          xml.tag!("indicador", "1")
          xml.tag!("codigo-seguranca", parameters[:csc].to_s)
          xml.tag!("nome-portador", parameters[:nome].to_s) if parameters[:nome]
        end if parameters[:numero]
        xml.tag!("dados-pedido") do
          xml.numero parameters[:pedido].to_s
          xml.valor parameters[:valor].to_s
          xml.moeda parameters[:moeda].to_s
          xml.tag!("data-hora", parameters[:"data-hora"])
          xml.descricao parameters[:descricao].to_s if parameters[:descricao]
          xml.idioma parameters[:idioma].to_s if parameters[:idioma]
        end
        xml.tag!("forma-pagamento") do
          [:bandeira, :produto, :parcelas].each do |key|
            xml.tag!(key.to_s, parameters[key].to_s)
          end
        end
        xml.tag!("url-retorno", parameters[:"url-retorno"])
        xml.autorizar parameters[:autorizar].to_s
        xml.capturar parameters[:capturar].to_s
        xml.tag!("campo-livre", parameters[:"campo-livre"]) if parameters[:"campo-livre"]
        xml.bin parameters[:bin].to_s if parameters[:bin]
      end
      make_request! message
    end

    def autorizacao!(parameters={})
    end
    
    def captura!(cielo_tid)
      return nil unless cielo_tid
      message = xml_builder("requisicao-captura", :before) do |xml|
        xml.tid "#{cielo_tid}"
      end
      make_request! message
    end

    def cancelamento!(tid)
      return nil unless tid
      message = xml_builder("requisicao-cancelamento", :before) do |xml|
        xml.tid "#{tid}"
      end 
      make_request! message
    end

    def consulta_tid(tid)
      return nil unless tid
      message = xml_builder("requisicao-consulta", :before) do |xml|
        xml.tid "#{tid}"
      end 
      make_request! message
    end

    def autorizacao_direta!(parameters={})
      valida_autorizacao_direta parameters
      message = xml_builder("requisicao-transacao") do |xml|
        xml.tag!("dados-portador") do
          xml.tag!("numero", parameters[:numero].to_s)
          xml.tag!("validade", parameters[:validade].to_s)
          xml.tag!("indicador", "1")
          xml.tag!("codigo-seguranca", parameters[:csc].to_s)
          xml.tag!("nome-portador", parameters[:nome].to_s) if parameters[:nome]
        end
        xml.tag!("dados-pedido") do
          xml.numero parameters[:pedido].to_s
          xml.valor parameters[:valor].to_s
          xml.moeda parameters[:moeda].to_s
          xml.tag!("data-hora", parameters[:"data-hora"])
          xml.descricao parameters[:descricao].to_s if parameters[:descricao]
          xml.idioma parameters[:idioma].to_s if parameters[:idioma]
        end
        xml.tag!("forma-pagamento") do
          [:bandeira, :produto, :parcelas].each do |key|
            xml.tag!(key.to_s, parameters[key].to_s)
          end
        end
        xml.tag!("url-retorno", parameters[:"url-retorno"])
        xml.autorizar "3"
        xml.capturar parameters[:capturar].to_s
      end
      make_request! message
    end

    def consulta_pedido(pedido)
      return nil unless pedido
      message = xml_builder("requisicao-consulta-chsec", :before) do |xml|
        xml.tag!("numero-pedido", pedido.to_s)
      end 
      make_request! message
    end
    
    private

      def set_default(parameters={})
        parameters.merge!(:moeda => "986") unless parameters[:moeda]
        parameters.merge!(:"data-hora" => Time.now.strftime("%Y-%m-%dT%H:%M:%S")) unless parameters[:"data-hora"]
        parameters.merge!(:produto => "1") unless parameters[:produto]
        parameters.merge!(:parcelas => "1") unless parameters[:parcelas]
        if parameters[:bandeira].nil? && parameters[:numero]
          bandeira = number_to_brand(parameters[:numero])
          parameters.merge!(:bandeira => bandeira)
        end
        parameters[:bandeira].downcase! unless parameters[:bandeira].nil?
        parameters[:valor] = (parameters[:valor] * 100).to_i
      end

      def number_to_brand(number)
        if (number.to_s[0,1] == "4")
          "visa"
        elsif (51..55).include? number.to_s[0,2].to_i
          "mastercard"
        elsif (number.to_s[0,2] == "36")
          "diners"
        elsif number.to_s[0,2] == "65" ||number.to_s[0,4] == "6011" || (644..649).include?(number.to_s[0,3].to_i) || (622126..622925).include?(number.to_s[0,6].to_i)
          "discover"
        else
          nil
        end
      end

      def valida_criacao(parameters={})
        set_default parameters
        parameters.merge!(:"url-retorno" => Cielo.return_path) unless parameters[:"url-retorno"]
        required = [:pedido, :valor, :moeda, :"data-hora", :bandeira, :produto, :parcelas, :"url-retorno", :autorizar, :capturar]
        required.push(:numero, :validade, :csc) if parameters[:numero]
        required.each do |parameter|
          raise Cielo::MissingArgumentError, "Required parameter #{parameter} not found" unless parameters[parameter]
        end
      end

      def valida_autorizacao_direta(parameters={})
        set_default parameters
        required = [:numero, :validade, :csc, :pedido, :valor, :moeda, :"data-hora", :bandeira, :produto, :parcelas, :capturar]
        required.each do |parameter|
          raise Cielo::MissingArgumentError, "Required parameter #{parameter} not found" unless parameters[parameter]
        end
      end
      
      def xml_builder(group_name, target=:after, &block)
        xml = Builder::XmlMarkup.new
        xml.instruct! :xml, :version=>"1.0", :encoding=>"ISO-8859-1"
        xml.tag!(group_name, :id => "#{Time.now.to_i}", :versao => "1.1.1") do
          block.call(xml) if target == :before
          xml.tag!("dados-ec") do
            xml.numero Cielo.numero_afiliacao
            xml.chave Cielo.chave_acesso
          end
          block.call(xml) if target == :after
        end
        xml
      end
      
      def make_request!(message)
        params = { :mensagem => message.target! }
        
        result = @connection.request! params
        parse_response(result)
      end
      
      def parse_response(response)
        case response
        when Net::HTTPSuccess
          document = REXML::Document.new(response.body)
          parse_elements(document.elements)
        else
          {:erro => { :codigo => "000", :mensagem => "Impossível contactar o servidor"}}
        end
      end
      def parse_elements(elements)
        map={}
        elements.each do |element|
          element_map = {}
          element_map = element.text if element.elements.empty? && element.attributes.empty?
          element_map.merge!("value" => element.text) if element.elements.empty? && !element.attributes.empty?
          element_map.merge!(parse_elements(element.elements)) unless element.elements.empty?
          map.merge!(element.name => element_map)
        end
        map.symbolize_keys
      end
  end
end