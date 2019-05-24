# This is a big gulp of copying.
require 'fileutils'
module Make
  include FileUtils
 
  #  Windows compile.  Copy the static stuff, Copy the ruby libs
  #  Then copy the deps.
  def static_setup (so_list)
    $stderr.puts "setup: dir=#{`pwd`}"
    rbvt = APP['RUBY_V']
    rbvm = APP['RUBY_V'][/^\d+\.\d+/]
    # remove leftovers from previous rake.
    rm_rf "#{TGT_DIR}/lib"
    rm_rf "#{TGT_DIR}/etc"
    rm_rf "#{TGT_DIR}/share"
    rm_rf "#{TGT_DIR}/conf.d"
    mkdir_p "#{TGT_DIR}/fonts"
    cp_r "fonts", "#{TGT_DIR}"
    mkdir_p "#{TGT_DIR}/lib"
    cp   "lib/shoes.rb", "#{TGT_DIR}/lib"
    cp_r "lib/shoes", "#{TGT_DIR}/lib"
    cp_r "lib/exerb", "#{TGT_DIR}/lib"
    cp_r "lib/package", "#{TGT_DIR}/lib"
    cp_r "samples", "#{TGT_DIR}/samples"
    cp_r "static", "#{TGT_DIR}/static"
    cp   "README.md", "#{TGT_DIR}/README.txt"
    cp   "CHANGELOG", "#{TGT_DIR}/CHANGELOG.txt"
    cp   "COPYING", "#{TGT_DIR}/COPYING.txt"
    #mkdir_p "#{TGT_DIR}/lib"
    cp_r "#{EXT_RUBY}/lib/ruby", "#{TGT_DIR}/lib", remove_destination: true
    # copy include files
    mkdir_p "#{TGT_DIR}/lib/ruby/include/ruby-#{rbvt}"
    cp_r "#{EXT_RUBY}/include/ruby-#{rbvt}/", "#{TGT_DIR}/lib/ruby/include"
    
    if APP['LIBPATHS']
      win_dep_find_and_copy( APP['LIBPATHS'], so_list)
    else
      so_list.each_value do |path|
        cp "#{path}", "#{TGT_DIR}"
      end
    end
    # copy/setup etc/share
    mkdir_p "#{TGT_DIR}/share/glib-2.0/schemas"
    cp  "#{ShoesDeps}/share/glib-2.0/schemas/gschemas.compiled" ,
        "#{TGT_DIR}/share/glib-2.0/schemas"
    cp_r "#{ShoesDeps}/share/fontconfig", "#{TGT_DIR}/share"
    cp_r "#{ShoesDeps}/share/themes", "#{TGT_DIR}/share"
    cp_r "#{ShoesDeps}/share/xml", "#{TGT_DIR}/share"
    cp_r "#{ShoesDeps}/share/icons", "#{TGT_DIR}/share"
    sh "#{WINDRES} -I. shoes/appwin32.rc shoes/appwin32.o"
    cp_r "#{ShoesDeps}/etc", TGT_DIR
    if ENABLE_MS_THEME
      # Not available in later Gtk3's. Harmless
      ini_path = "#{TGT_DIR}/etc/gtk-3.0"
      mkdir_p ini_path
      File.open "#{ini_path}/settings.ini", mode: 'w' do |f|
        f.write "[Settings]\n"
        f.write "#gtk-theme-name=win32\n"
      end
    end
    # BECAUSE we are using deps from msys2 and pacman, we need
    # to copy some dlls and update the gdk-pixbuf info. 
    # Update also needs to be run at install time.
    mkdir_p "#{TGT_DIR}/lib"
    cp_r "#{ShoesDeps}/lib/gdk-pixbuf-2.0", "#{TGT_DIR}/lib"
    ENV['GDK_PIXBUF_MODULEDIR'] = "#{TGT_DIR}\\lib\\gdk-pixbuf-2.0\\2.10.0/loaders"
    ENV['GDK_PIXBUF_MODULE_FILE'] = "#{TGT_DIR}\\lib/gdk-pixbuf-2.0\\2.10.0\\loaders.cache"
    rm "#{TGT_DIR}/lib/gdk-pixbuf-2.0/2.10.0/loaders.cache"
    sh "gdk-pixbuf-query-loaders.exe --update-cache"
    
    cp_r "#{ShoesDeps}/lib/gtk-3.0", "#{TGT_DIR}/lib" 
    bindir = "#{ShoesDeps}/bin"
    if File.exist?("#{bindir}/gtk-update-icon-cache-3.0.exe")
      cp "#{bindir}/gtk-update-icon-cache-3.0.exe",
            "#{TGT_DIR}/gtk-update-icon-cache.exe"
    else 
      cp  "#{bindir}/gtk-update-icon-cache.exe", TGT_DIR
    end
    cp "#{bindir}/gdk-pixbuf-query-loaders.exe", TGT_DIR

    cp APP['icons']['win32'], "shoes/appwin32.ico"
  end
end

