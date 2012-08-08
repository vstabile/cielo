#encoding: utf-8
module Cielo
  def self.status
    {
      0 => 'Criada',
      1 => 'Em andamento',
      2 => 'Autenticada',
      3 => 'Não autenticada',
      4 => 'Autorizada ou pendente de captura',
      5 => 'Não autorizada',
      6 => 'Capturada',
      8 => 'Não capturada',
      9 => 'Cancelada',
      10 => 'Em autenticação'
    }
  end
end