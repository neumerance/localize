def json_success_string
  '{"status":{"code":0, "message":"success"}, "response": null}'
end

def json_error_string
  '{"status":{"code":23, "message":"some error"}, "response": null}'
end

def json_garbage_string
  'garbage'
end

def json_wrong_formats
  [json_no_status, json_no_code, json_no_message, json_no_response]
end

def json_no_status
  '{"status1":{"code":0, "message":"success"}, "response": null}'
end

def json_no_code
  '{"status":{"code1":0, "message":"success"}, "response": null}'
end

def json_no_message
  '{"status":{"code":0, "message1":"success"}, "response": null}'
end

def json_no_response
  '{"status":{"code":0, "message":"success"}, "response1": null}'
end
