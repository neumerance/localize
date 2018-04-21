require 'spec_helper'
require 'rails_helper'
require 'support/utils_helper'

describe TextResourcesController, type: :controller do
  include ActionDispatch::TestProcess
  include UtilsHelper
  render_views

  let!(:client) { FactoryGirl.create(:client) }
  let!(:translator) { FactoryGirl.create(:translator) }
  let!(:useraccount) { FactoryGirl.create(:user_account, owner_id: client.id, type: 'UserAccount', balance: 847.08, currency_id: 1) }
  let!(:text_resource) { FactoryGirl.create(:text_resource, client: client, language_id: 1) }
  let!(:resource_string) { FactoryGirl.create(:resource_string, text_resource: text_resource) }
  let!(:string_translation) { FactoryGirl.create(:string_translation, resource_string: resource_string, language_id: 2, status: 3) }
  let!(:resource_language) { FactoryGirl.create(:resource_language, text_resource: text_resource, language_id: 2) }
  let!(:resource_chat) { FactoryGirl.create(:resource_chat, translator: translator, resource_language: resource_language) }
  let!(:managed_work) do
    FactoryGirl.create(:managed_work, owner_id: resource_language.id, owner_type: 'ResourceLanguage', from_language_id: 1,
                                      to_language_id: 2, client_id: client.id)
  end

  context 'Confirm word count' do
    before { login_as(client) }

    it 'should have new string count' do

      get :show, params: { id: text_resource.id }
      expect(response).to have_http_status(200)
      expect(response.body).to include("Words not funded: #{resource_language.count_untraslated_words}")
    end

    it 'should have word count ready for translation' do
      resource_chat.resource_language.pay
      get :show, params: { id: text_resource.id }
      expect(response).to have_http_status(200)
      expect(response.body).to include("Words funded, waiting for translation: #{resource_language.selected_chat.word_count}")
    end

    it 'should have word count of 0' do
      resource_string.cleanup_and_refund
      resource_string.destroy
      get :show, params: { id: text_resource.id }
      expect(response).to have_http_status(200)
      expect(response.body).to include('Words not funded: 0')
    end
  end

  context '#create' do
    let(:params) do
      {
        'text_resource' => {
          'name' => 'Cookie 2018 - Jam Blast Crush Match 3 Puzzle Games',
          'description' => "\r\nPlay match game in over 500+ fun cookies crush match 3 levels and help Chef Panda match and crunch through hundreds of exciting levels! Work your way through increasingly challenging puzzles and gain the boosters to pass levels in your bakery adventure. Download & Play Now!\r\n\r\nCookie 2018 is a fun,
 new match 3 style puzzle cookie games developed by free match 3 games to play offline!\r\n\r\nHIGHLIGHTS\r\n• TONS OF LEVELS\r\n- Over 500 awesome levels! Updates will be continued! \r\n\r\n• UNIQUE GAME WORLDS\r\n- Explore unique game worlds,
 each with their own stories and characters.\r\n- Collect your favorite characters to get free boosters!\r\n\r\n• CHALLENGING AND FUN PLAY\r\n- Gather powerful boosters to beat the toughest stages.\r\n- Connect with Facebook to get help from friends.\r\n\r\n• NO WIFI? NO PROBLEM!\r\n- You can play offline in anytime in the cookie blast jam 2018\r\n\r\nHOW TO PLAY\r\n• Swap and Match at least 3 yummy cookies of the same type to burst!\r\n• Cookie crush match 4 to get a striped treat of this color and create a line blast.\r\n• Match 5 candy treats in an L or T form to get a bomb will explode all items around it.\r\n• Match 5 sweet cookies in a row to get a special colorful rainbow candy item.\r\n• Make unique combinations to get rainbow cookie crush bombs.\r\n• Use rainbow cookie crush bombs to remove the yummy cookies as many as you can!\r\n• Aim to use the least moves to achieve goal! \r\n• Play more levels to activate new characters and collect boosters!\r\n• Achieve 3 stars for each level to get more boosters!\r\n• Leverage powerful boosters to help clear obstacles!\r\n\r\nFEATURES\r\n🍪Free to play and fun for everyone!\r\n🍪Totally cookie games free for all players and fascinating graphics with special design cookie crush blast.\r\n🍪Classic cookie games,
 you can make thousands of not only sugar smash but also sweet cookies and confounding candies here!\r\n🍪Let's recreate the cupcake and sugar smash matching 3 sweet games around the world!\r\n🍪Unique and delicious dessert set with cookie fever and in each levels brings you tons of sweet challenges.\r\n🍪It’s easy but challenging and takes you to delightful candy journey to get master of cookie jam blast.\r\n🍪Cookies 2018 is a very addictive crush games free. Once you pop,
 you can't stop this match three games\r\n🍪Simple,
 fun,
 and casual match games free gameplay!\r\n🍪Play with friends to challenge and see who get the high scores\r\n🍪Leaderboards to watch your friends and competitors!\r\n\r\nBOOSTERS\r\n✔ Cookie Pop: popcorn collect & crush sweet biscuit cookies in a 9-cell region\r\n✔ Tasty Ice Cream Cookie: get & jam all sugar cookies jelly on the column or row\r\n✔ Extra Candy Time: add 5 seconds to the sugar puzzle\r\n✔ Candy Cake Pops: get & jam all yummy food have same color\r\n✔ Balloon crush: use the spider to crush delicious food\r\n✔ Cookie Rush Time: double score you get in 10 seconds\r\n\r\nGet Cookie 2018 - Jam Blast Crush Match 3 Puzzle Games now from Google Play only if you love match three games free for android! Enjoy the best free simple match 3 games that are not timed.\r\nThis game is seriously fun,
 super addictive and we can’t promise you will not fall in love with our awesome and delicious cookie adventure. \r\n\r\n❤❤❤ Have fun playing Cookie 2018 crushing games! ❤❤❤",
          'category_id' => '30',
          'required_text' => '<,,"',
          'check_standard_regex' => '1',
          'language_id' => '1',
          'owner_type' => '',
          'owner_id' => ''
        },
        'language' => {
          '4' => '1',
          '3' => '1',
          '27' => '1',
          '28' => '1',
          '43' => '1',
          '46' => '1',
          '2' => '1'
        },
        'commit' => 'Create project'
      }
    end

    before { login_as(client) }

    it do
      post :create, params: params
      expect(response).to redirect_to(text_resource_path(TextResource.last))
    end
  end
end
