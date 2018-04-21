# Custom components
$: << "#{Rails.root}/components"
$: << "#{Rails.root}/lib"
ENCODING_JAVA = 0
ENCODING_UTF8 = 1
ENCODING_UTF16_LE = 2
ENCODING_UTF16_BE = 3

require 'keyword_project_language.rb'
require 'keyword_project_methods.rb'
require 'char_conversion.rb'
require 'chat_functions.rb'
require 'length_counter.rb'
require 'lockable.rb'
require 'notify_tas.rb'
require 'parent_with_siblings.rb'
require 'remembers.rb'
require 'trackable.rb'
require 'transaction_processor.rb'
require 'translateable_object.rb'
