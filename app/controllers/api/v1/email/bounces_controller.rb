class Api::V1::Email::BouncesController < ActionController::API
  def create
    json = JSON.parse(request.body.read)
    unless json['notificationType'].present?
      logger.info("BouncesController - Received an invalid notification: #{json}")
      head 400
      return
    end
    processor = ProcessEmailBounces.new(json)
    processor.call
    head 200
  end
end
