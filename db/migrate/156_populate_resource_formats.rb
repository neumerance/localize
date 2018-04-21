class PopulateResourceFormats < ActiveRecord::Migration

	FORMATS = [['Java','Java Unicode resource', nil, nil, '=', "\\", nil, nil, ENCODING_JAVA, 0],
				['Delphi','Delphi Unicode resource', nil, '"', '=', nil, nil, '[', ENCODING_UTF16_LE, 0],
				['iPhone','Apple iPhone Unicode resource', '"', '"', '=', nil, nil, '[', ENCODING_UTF16_LE, 0]]

	def self.up
		FORMATS.each do |r|
			rf = ResourceFormat.create!(:name=>r[0], :description=>r[1], :label_delimiter=>r[2],:text_delimiter=>r[3],
						:separator_char=>r[4],:multiline_char=>r[5], :end_of_line=>r[6],
						:comment_char=>r[7], :encoding=>r[8], :line_break=>r[9])
		end
	end

	def self.down
		FORMATS.each do |r|
			rf = ResourceFormat.where(name: r[0]).first
			if rf
				rf.destroy
			end
		end
	end
end
