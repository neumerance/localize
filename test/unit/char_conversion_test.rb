require File.dirname(__FILE__) + '/../test_helper'

include CharConversion

class CharConversionTest < ActiveSupport::TestCase
  def test_utf16le_handling
    # --- reference file
    ref = read_fixture_file('sample_utf8.txt', 'UTF-8')

    # --- UTF-16 Little Endian (Standard Windows)
    # get the test file
    txt = read_fixture_file('sample_utf16le.txt')

    ## unencode
    res = unencode_string(txt, ENCODING_UTF16_LE, true)
    assert res
    # compare against the reference file

    assert_equal res, ref

    ## encode back
    back = encode_string(res, ENCODING_UTF16_LE, true)
    assert back
    assert_equal back, txt.force_encoding(UTF16_NAMES[ENCODING_UTF16_LE])
  end

  def test_utf16be_handling
    # --- reference file
    ref = read_fixture_file('sample_utf8.txt', 'UTF-8')

    # --- UTF-16 Big Endian (Motorola)
    # get the test file
    txt = read_fixture_file('sample_utf16be.txt')

    ## unencode
    res = unencode_string(txt, ENCODING_UTF16_BE, true)
    assert res
    assert_equal res, ref

    ## encode back
    back = encode_string(res, ENCODING_UTF16_BE, true)
    assert back
    assert_equal back, txt.force_encoding(UTF16_NAMES[ENCODING_UTF16_BE])
  end

  def test_java_unicode_handling
    # --- reference file
    ref = read_fixture_file('sample_utf8.txt', 'UTF-8')

    # --- Java resource
    # get the test file
    txt = read_fixture_file('sample_java.txt')

    # unencode
    res = unencode_string(txt, ENCODING_JAVA, true)
    assert res

    # compare against the reference file
    assert_equal res, ref

    # encode back
    back = encode_string(res, ENCODING_JAVA, true)
    assert back
    assert_equal back, txt
  end

  def read_fixture_file(file_name, encoding = 'ASCII-8BIT')
    file_path = File.join(Rails.root, 'test/fixtures/char_conversion/', file_name)
    f = File.open(file_path, 'rb', encoding: encoding)
    content = f.read
    f.close

    content
  end
end
