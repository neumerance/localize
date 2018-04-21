class TemporaryUser < Client
  def verified?
    false
  end

  def self.gen_new
    curtime = Time.now

    u = create!(email: "unreg#{curtime.to_i}@icanlocalize.com",
                signup_date: curtime,
                fname: "fname#{curtime.to_i}",
                lname: "lname#{curtime.to_i}",
                nickname: "unreg#{curtime.to_i}",
                password: "pw#{curtime.to_i}")
    u
  end
end
