require 'test_helper'

SELECT_DATASET_BUTTON = '//button[.="BioMart"]'
ENSEMBL_GENES_MENU_ITEM = '//a[span[.="ENSEMBL 55 GENES (SANGER UK)"]]'
ENSEMBL_GENES_HUMAN_MENU_ITEM = '//a[span[.="Homo sapiens genes (GRCh37)"]]'

class ApplicationTest < ActionController::IntegrationTest

  context 'home page' do
    setup do
      visit root_path
      assert true
    end

    should 'display biomart' do
      assert_contain 'biomart'
    end
  end

  context 'martview' do
    should 'have basic layout' do
      visit '/martview/'
      assert_have_selector 'div.header'
      assert_have_selector 'div.footer'
    end
    
    should 'select dataset using menu items' do
      selenium.open '/martview/'
      selenium.wait_for_element SELECT_DATASET_BUTTON
      selenium.click SELECT_DATASET_BUTTON
      selenium.wait_for_element ENSEMBL_GENES_MENU_ITEM
      selenium.mouse_over ENSEMBL_GENES_MENU_ITEM
      selenium.wait_for_element ENSEMBL_GENES_HUMAN_MENU_ITEM
      selenium.click ENSEMBL_GENES_HUMAN_MENU_ITEM
      assert_contain 'ENSEMBL 55 GENES'
    end

    should 'select dataset using url params' do
      selenium.open '/martview/?mart=msd&dataset=msd'
      assert_contain 'MSD'
    end
  end
end
