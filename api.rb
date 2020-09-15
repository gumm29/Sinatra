require 'sinatra'
require 'mongoid'
require 'jwt'

Mongoid.load! 'mongoid.config'

class Produto
  include Mongoid::Document

  field :nome, type: String
  field :descricao, type: String
  field :preco, type: String

  validates :nome, presence: true
  validates :descricao, presence: true
  validates :preco, presence: true

  index({ nome: 'text' })
  index({ preco: 1 }, { unique: true, name: 'preco_index' })

  scope :nome, -> (nome) { where(nome: /^#{nome}/)}
  scope :descricao, -> (descricao) { where(descricao: descricao)}
  scope :preco, -> (preco) { where(preco: preco)}
end

get '/' do
  erb :index
end

get '/teste' do
  'teste'
end

class Serializador
  def initialize(produto)
    @produto = produto
  end

  def as_json(*)
    data = {
      id: @produto.id.to_s,
      nome: @produto.nome,
      descricao: @produto.descricao,
      preco: @produto.preco
    }

    data[:errors] = @produto.errors if @produto.errors.any?
    data
  end
end

get '/produtos' do
  content_type 'application/json'

  produto = Produto.all

  [:nome, :descricao, :preco].each do |f|
    produto = produto.send(f, params[f]) if params[f]
  end

  produto.map { |prod| Serializador.new(prod) }.to_json
end

get '/produtos/:nome' do |nome|
  content_type 'application/json'
  produto = Produto.where(nome: nome).first
  halt(404, { message:'Produto nao encontrado'}.to_json) unless produto
  Serializador.new(produto).to_json
end

helpers do
  def base_url
    @base_url ||= "#{request.env['rack.url_scheme']}://{request.env['HTTP_HOST']}"
  end

  def json_params
    begin
      JSON.parse(request.body.read)
    rescue
      halt 400, { message:'Invalid JSON' }.to_json
    end
  end
end

post '/produtos' do
  produto = Produto.new(json_params)
  if produto.save
    response.headers['Location'] = "#{base_url}/produtos/#{produto.id}"
    status 201
  else
    status 422
    body Serializador.new(produto).to_json
  end
end

patch '/produtos/:id' do |id|
  produto = Produto.where(id: id).first
  halt(404, { message: 'produto nao encontrado' }.to_json) unless produto
  if produto.update_attributes(json_params)
    Serializador.new(produto).to_json
  else
    status 422
    body Serializador.new(produto).to_json
  end
end

delete '/produtos/:id' do |id|
  produto = Produto.where(id: id).first
  produto.destroy if produto
  status 204
end

post '/token' do
  exp = Time.now.to_i + 4 * 3600
  payload = { data: { user: 'gustavo', senha: '123456'}, exp: exp }

  # hmac_secret = 'senha123456'

  rsa_private = OpenSSL::PKey::RSA.generate 2048
  rsa_public = rsa_private.public_key

  token = JWT.encode payload, rsa_private, 'RS256'

  # eyJhbGciOiJSUzI1NiJ9.eyJkYXRhIjoidGVzdCJ9.GplO4w1spRgvEJQ3-FOtZr-uC8L45Jt7SN0J4woBnEXG_OZBSNcZjAJWpjadVYEe2ev3oUBFDYM1N_-0BTVeFGGYvMewu8E6aMjSZvOpf1cZBew-Vt4poSq7goG2YRI_zNPt3af2lkPqXD796IKC5URrEvcgF5xFQ-6h07XRDpSRx1ECrNsUOt7UM3l1IB4doY11GzwQA5sHDTmUZ0-kBT76ZMf12Srg_N3hZwphxBtudYtN5VGZn420sVrQMdPE_7Ni3EiWT88j7WCr1xrF60l8sZT3yKCVleG7D2BEXacTntB7GktBv4Xo8OKnpwpqTpIlC05dMowMkz3rEAAYbQ
  # puts token

  # decoded_token = JWT.decode token, rsa_public, true, { algorithm: 'RS256' }

  # puts decoded_token
end