assert = chai.assert
sinon.assert.expose assert, prefix: null
sandbox = sinon.sandbox.create()

describe 'streamer', ->
  WebSocket = null
  fakeSock = null
  streamer = null

  beforeEach module('h.streamer')

  beforeEach module ($provide, streamerProvider) ->
    fakeSock = {
      send: sandbox.spy()
      close: sandbox.spy()
    }
    WebSocket = sandbox.stub().returns(fakeSock)
    $provide.decorator '$window', ($delegate) ->
      angular.extend $delegate, {WebSocket}
    streamerProvider.url = 'http://magicstreemz/giraffe'
    return

  beforeEach inject (_streamer_) ->
    streamer = _streamer_

  afterEach ->
    sandbox.restore()

  it 'creates a socket with the correct base URL', ->
    streamer.open()

    assert.calledWith(WebSocket, 'http://magicstreemz/giraffe')

  it 'does not open another socket while a socket is connecting', ->
    streamer.open()
    streamer.open()

    assert.calledOnce(WebSocket)

  it 'queues messages until the socket is open', ->
    streamer.open()
    streamer.send({animal: 'elephant'})

    assert.notCalled(fakeSock.send)

    fakeSock.onopen()

    assert.called(fakeSock.send)

  it 'preserves message ordering in the queue', ->
    streamer.open()
    streamer.send({animal: 'elephant'})
    streamer.send({animal: 'giraffe'})
    fakeSock.onopen()

    firstAnimal = JSON.parse(fakeSock.send.getCall(1).args[0]).animal
    secondAnimal = JSON.parse(fakeSock.send.getCall(2).args[0]).animal
    assert.equal(firstAnimal, 'elephant')
    assert.equal(secondAnimal, 'giraffe')

  it 'converts message data to JSON', ->
    streamer.open()
    streamer.send({animal: 'badger'})
    fakeSock.onopen()

    assert.calledWith(fakeSock.send, JSON.stringify({animal: 'badger'}))

  it 'sends a client ID as the first message once the socket opens', ->
    streamer.send({animal: 'elephant'})
    streamer.open()
    fakeSock.onopen()

    msg = fakeSock.send.getCall(0).args[0]
    data = JSON.parse(msg)
    assert.equal(data.messageType, 'client_id')
    assert.equal(typeof data.value, 'string')

  it 'attempts to reopen the socket on connection failure', ->
    clock = sandbox.useFakeTimers()

    streamer.open()
    fakeSock.onclose()

    clock.tick(500)

    assert.calledTwice(WebSocket)

  it 'closes the socket when close is called', ->
    streamer.open()
    streamer.close()

    assert.calledOnce(fakeSock.close)

  it 'only closes the socket once', ->
    streamer.open()
    streamer.close()
    streamer.close()

    assert.calledOnce(fakeSock.close)

  it 'does not try and reopen the socket when closed explicitly', ->
    clock = sandbox.useFakeTimers()
    streamer.open()
    streamer.close()
    fakeSock.onclose()

    clock.tick(500)
    assert.calledOnce(WebSocket)

  it 'calls the onmessage handler when the socket receives a message', ->
    streamer.onmessage = sinon.spy()
    streamer.open()
    fakeSock.onmessage(data: JSON.stringify({animal: 'baboon'}))
    assert.called(streamer.onmessage)

  it 'calls the onmessage handler with parsed JSON', ->
    streamer.onmessage = sinon.spy()
    streamer.open()
    fakeSock.onmessage(data: JSON.stringify({animal: 'baboon'}))
    assert.calledWith(streamer.onmessage, {animal: 'baboon'})