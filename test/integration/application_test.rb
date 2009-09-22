require 'test_helper'

SELECT_DATASET_BUTTON = '//button[.="BioMart"]'
ENSEMBL_GENES_MENU_ITEM = '//a[span[.="ENSEMBL 55 GENES (SANGER UK)"]]'
ENSEMBL_GENES_HUMAN_MENU_ITEM = '//a[span[.="Homo sapiens genes (GRCh37)"]]'

HEADER_PANEL = '//*[@id="header"]'
SEARCH_PANEL = '//*[@id="search"]'
RESULTS_PANEL = '//*[@id="results"]'
FOOTER_PANEL = '//*[@id="footer"]'

class ApplicationTest < ActionController::IntegrationTest

  context 'The home page' do
    test 'should display biomart' do
      visit root_path
      assert_contain 'biomart'
    end
  end

  context 'Martview' do
    test 'should display header, search, results and footer panels' do
      visit '/martview/'
      assert_have_xpath HEADER_PANEL
      assert_have_xpath SEARCH_PANEL
      assert_have_xpath RESULTS_PANEL
      assert_have_xpath FOOTER_PANEL
    end

    test 'should let the user select a dataset using the select dataset menu' do
      visit '/martview/'
      selenium.wait_for_element SELECT_DATASET_BUTTON
      selenium.click SELECT_DATASET_BUTTON
      selenium.wait_for_element ENSEMBL_GENES_MENU_ITEM
      selenium.mouse_over ENSEMBL_GENES_MENU_ITEM
      selenium.wait_for_element ENSEMBL_GENES_HUMAN_MENU_ITEM
      selenium.click ENSEMBL_GENES_HUMAN_MENU_ITEM
      assert_contain 'ENSEMBL 55 GENES'
    end

    test 'should select a dataset using url params' do
      visit '/martview/?mart=msd&dataset=msd'
      assert_contain 'MSD'
    end
  end
end
