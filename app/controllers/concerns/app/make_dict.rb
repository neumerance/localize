module App
  module MakeDict
    def make_dict(scan_hash)
      res_h = {}
      res_l = []
      log = ''
      return [] if scan_hash.nil?
      scan_hash.each do |k, v|
        res_h[Integer(k)] = v == '1' ? true : false
        res_l << Integer(k) if v == '1'
      end
      res_l
    end
  end
end
