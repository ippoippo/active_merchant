require 'test_helper'

# == Description
# ECONTEXT supports both Credit Card based operations, and those where a token is provided
# which represents Credit Card details previously stored with ECONTEXT
#
# This test class will test the options where CREDIT CARD details are supplied.
#
class RemoteEcontextTest < Test::Unit::TestCase
  def setup
    @gateway = EcontextGateway.new(fixtures(:econtext))

    @amount = 10000
    # TODO Why does this fail, this should be a CVV2 checked card
    # @credit_card = credit_card('4123450131003312',
    #                            {:brand => 'visa',
    #                             :verification_value => '815',
    #                             :month => 3,
    #                             :year => (Time.now.year + 1),
    #                            })

    @credit_card = credit_card('4980111111111111',
                               {:brand => 'visa',
                                :verification_value => '815',
                                :month => 3,
                                :year => (Time.now.year + 1),
                               })

    @declined_card_c1430 = credit_card('4980111111111112',
                                       {:brand => 'visa',
                                        :verification_value => '815',
                                        :month => 3,
                                        :year => (Time.now.year + 1),
                                       })
    @declined_card_c1483 = credit_card('4980111111111113',
                                       {:brand => 'visa',
                                        :verification_value => '815',
                                        :month => 3,
                                        :year => (Time.now.year + 1),
                                       })

    @options = {
        order_id: Time.now.getutc.strftime("%Y%m%d%H%M%S%L"),
        description: 'dummy'
    }
  end

  def test_failure_store
    stamp = Time.now.getutc.strftime("%Y%m%d%H%M%S%L")
    options = {
        customer: stamp,
    }
    assert_raise(ArgumentError){  @gateway.store('111111', options) }
  end

  def test_successful_purchase
    stamp = Time.now.getutc.strftime("%Y%m%d%H%M%S%L")
    options = {
        order_id: stamp,
        description: "#{stamp}Sale"
    }
    response = @gateway.purchase(@amount, @credit_card, options)
    assert_success response
    assert_equal '正常', response.message
  end

  def test_failed_purchase_c1430
    response = @gateway.purchase(@amount, @declined_card_c1430, @options)
    assert_failure response
    assert_equal 'C1430', response.params['infocode']
    assert_equal '-7', response.params['status']
    assert_equal 'カード与信失敗(02-00)', response.message
  end

  def test_failed_purchase_c1483
    response = @gateway.purchase(@amount, @declined_card_c1483, @options)
    assert_failure response
    assert_equal 'C1483', response.params['infocode']
    assert_equal '-7', response.params['status']
    assert_equal 'カード与信失敗(01-04)', response.message
  end

  def test_successful_authorize_and_capture
    stamp = Time.now.getutc.strftime("%Y%m%d%H%M%S%L")
    options = {
        order_id: stamp,
        description: "#{stamp}Auth"
    }
    auth = @gateway.authorize(@amount, @credit_card, options)
    assert_success auth
    assert_equal '正常', auth.message

    options = {
        order_id: stamp
    }
    assert capture = @gateway.capture(@amount, auth.authorization, options)
    assert_success capture
    assert_equal '正常', capture.message
  end

  def test_failed_authorize_c1430
    response = @gateway.authorize(@amount, @declined_card_c1430, @options)
    assert_failure response
    assert_equal 'C1430', response.params['infocode']
    assert_equal '-7', response.params['status']
    assert_equal 'カード与信失敗(02-00)', response.message
  end

  def test_partial_capture
    # NOT SUPPORTED BY ECONTEXT
  end

  def test_failed_capture
    stamp = Time.now.getutc.strftime("%Y%m%d%H%M%S%L")
    options = {
        order_id: stamp,
    }
    response = @gateway.capture(@amount, nil, options)
    assert_failure response
  end

  def test_successful_refund_from_a_purchase
    stamp = Time.now.getutc.strftime("%Y%m%d%H%M%S%L")
    options = {
        order_id: stamp,
        description: "#{stamp}Sale"
    }
    purchase = @gateway.purchase(@amount, @credit_card, options)
    assert_success purchase

    assert refund = @gateway.refund(nil, purchase.authorization)
    assert_success refund
  end

  def test_successful_refund_from_a_auth_capture
    stamp = Time.now.getutc.strftime("%Y%m%d%H%M%S%L")
    options = {
        order_id: stamp,
        description: "#{stamp}Auth"
    }
    auth = @gateway.authorize(@amount, @credit_card, options)
    assert_success auth

    options = {
        order_id: stamp
    }
    assert capture = @gateway.capture(@amount, auth.authorization, options)
    assert_success capture

    assert refund = @gateway.refund(nil, capture.authorization)
    assert_success refund
  end


  def test_partial_refund
    stamp = Time.now.getutc.strftime("%Y%m%d%H%M%S%L")
    options = {
        order_id: stamp,
        description: "#{stamp}Sale"
    }
    purchase = @gateway.purchase(@amount, @credit_card, options)
    assert_success purchase

    # Send new amount, not the amount to refund (refund 6000 back to cardholder)
    assert refund = @gateway.refund(4000, purchase.authorization)
    assert_success refund
  end


  def test_failed_refund
    bad_auth = {
        ecn_token: '',
        user_token: '',
        previous_order_id: '111',
        previous_paymt_code: 'C10',
        card_aquirer_code: '',
    }
    response = @gateway.refund(nil, bad_auth)
    assert_failure response
  end

  def test_successful_void
    stamp = Time.now.getutc.strftime("%Y%m%d%H%M%S%L")
    options = {
        order_id: stamp,
        description: "#{stamp}Auth"
    }
    auth = @gateway.authorize(@amount, @credit_card, options)
    assert_success auth

    assert void = @gateway.void(auth.authorization)
    assert_success void
  end

  def test_failed_void
    bad_auth = {
        ecn_token: '',
        user_token: '',
        previous_order_id: '111',
        previous_paymt_code: 'C10',
        card_aquirer_code: '',
    }
    response = @gateway.void(bad_auth)
    assert_failure response
  end

  def test_successful_verify
    assert_raise(NotImplementedError){ @gateway.verify(@credit_card, @options) }
  end

  def test_invalid_login
    gateway = EcontextGateway.new(
      shop_id: 'fake',
      chk_code: 'fake',
      live_url: 'http://www.example.com'
    )
    response = gateway.purchase(@amount, @credit_card, @options)
    assert_failure response
  end
  
end
