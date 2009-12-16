# Copyright (C) 2009 Pascal Rettig.

class Editor::MenuController < ParagraphController

  
  # Make sure we are the editor for menu and automenu paragraphs as well as site maps 
  editor_header "Navigation Paragraphs", :paragraph_navigation
  editor_for :automenu, :name => 'Automatic Menu', :features => ['menu'], :inputs => [ [ :path, 'Page Path',:integer ] ]
  editor_for :menu, :name => 'Links Menu', :features => ['menu']
  editor_for :site_map, :name => 'Site Map', :features => ['site_map']
  editor_for :bread_crumbs, :name => 'Bread Crumbs', :features => ['bread_crumb']

  def menu
  
      @data = @paragraph.data || {}
    
      @data[:menu] ||= []
      
      @pages = SiteNode.page_options()
  end
  
  def menu_save
     # Save the incoming paragraph
     item_keys = params[:item].keys
     item_keys.sort!
     
     
     
     last_level = 1
     data={:menu => [] }
     level_parents = [data]
     cur = data[:menu]
     item_keys.each do |item_key|
        item = params[:item][item_key]
        level = item[:level].to_i || 1
        item = { :title => item[:title],
                 :dest => item[:dest] == 'page' ? 'page' : 'url',
                 :url => item[:dest] == 'page' ? item[:url].to_i : item[:url] }
        level_parents[level] = item
        
        if(level == last_level)
          cur << item
          level_parents[level] = item
        elsif(level > last_level) 
          cur.last[:menu] ||= []
          cur = cur.last[:menu]
          cur << item
        else
          cur =  level_parents[level-1][:menu]
          cur << item
        end 
        last_level = level
     end
     
     @paragraph.data = data
     @paragraph.save
     # Then render a RJS template that renders the paragraph
     
     render_paragraph_update
  end
  
  class AutoMenuOptions < HashModel
      default_options :root_page => nil, :levels => nil, :excluded => [],:lock_level => 'no', :included => [], :include_path => false
      
      boolean_options :include_path
      integer_options :levels, :root_page
      validates_presence_of :root_page
      validates_presence_of :levels
  end
  
  def build_preview(root,levels,excluded,cur_level=1)
    page = root.is_a?(SiteNode) ?  root : SiteNode.find_by_id(root)
    
    return nil unless page 
    mnu = []
    elem_ids = []
    page.children.each do |page|
      page.menu.each do |pg|
        rev = pg.active_revision(@revision.language)
        if rev && !rev.menu_title.blank?
  	      title = rev.menu_title
        elsif rev &&  !rev.title.blank? 
          title = rev.title
        else
          title = pg.title.humanize
        end
        children,subelem_ids =  levels > 1 ? build_preview(pg,levels-1,excluded,cur_level+1) : [ nil,[]] 
        mnu << { :title => title,
          :node_id => pg.id,
          :excluded => excluded.include?(pg.id),
          :children => children
        }
        elem_ids += [pg.id] + subelem_ids
      end
    end
    [mnu,elem_ids]
  end
  
  def automenu
    data = params[:menu] || @paragraph.data
    data[:excluded] = ( data[:excluded] || []).collect { |elm| elm.to_i }.uniq
    data[:root_page] = data[:root_page].to_i if data[:root_page]
    data[:levels] = (data[:levels] || 0).to_i 
    @menu = AutoMenuOptions.new(data)

    @preview, @elem_ids = build_preview(data[:root_page],data[:levels].to_i,data[:excluded] || []) if data[:root_page]
    

    
    @pages = [['---Select Page---'.t,'']] + SiteNode.page_and_group_options("Site Root".t)
    @levels = [ ["1 Level",1] ] + 
      ( 2..5 ).to_a.collect do |num|
         [sprintf("%d Levels".t,num), num ]
      end
      
    if request.post?
      if @menu.valid?
        if @menu.lock_level != 'no'
          @menu.included = []
          @elem_ids.each { |elm| @menu.included << elm if(!@menu.excluded.include?(elm)) }
        end
        @paragraph.data = @menu.to_h
        @paragraph.save
        render_paragraph_update
        return
      end
    end
    
    if @menu.lock_level == 'yes' && !request.post?
      included = @menu.included || []
      @elem_ids.each { |elm| @menu.excluded << elm if !included.include?(elm) }
      @menu.excluded.uniq!
    end    
    
    @excluded = @menu.excluded
    
    render :action => 'automenu'
  end
  
  def automenu_preview()
    @excluded = ( params[:menu][:excluded] || []).collect { |elm| elm.to_i }
  
    @preview, @elem_ids = build_preview(params[:menu][:root_page],params[:menu][:levels].to_i,@excluded)
    render :partial => 'automenu_preview'
  end
  
  class SiteMapOptions < HashModel
      default_options :root_page => nil
  
  end
  
  def site_map
  
    data = params[:site_map] || @paragraph.data
    @options = SiteMapOptions.new(data)


  
    if request.post?
      if @options.valid?
        @options.root_page = @options.root_page.to_i
        @paragraph.data = @options.to_h
        @paragraph.save
        render_paragraph_update
        return
      end
    end
    
    @pages = [['Show Entire Site'.t,'']] + SiteNode.page_options
    
  end
  
  class BreadCrumbOptions < HashModel
      default_options :root_page => nil
  end
  
  def bread_crumbs
  
    data = params[:bread_crumbs] || @paragraph.data
    @options = BreadCrumbOptions.new(data)

    @pages = [['No Root Page'.t,'']] + SiteNode.page_options

  
    if request.post?
      if @options.valid?
        @options.root_page = @options.root_page.to_i
        @paragraph.data = @options.to_h
        @paragraph.save
        render_paragraph_update
        return
      end
    end
    
  end
  
end
