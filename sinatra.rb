require 'sinatra'
require 'json'

post '/payload' do
    $push = JSON.parse(request.body.read)
    status 201
end

get '/:name' do
  "Ola #{params['name']}, tudo bem?"
  if $push.inspect['numero'] == nil
    status 404
    'Campo \"numero\" vazio'
  else
    JSON({ :nome => params['name'], :numero => $push.inspect['numero']  })
  end
end