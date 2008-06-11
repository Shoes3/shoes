//
// shoes/native-cocoa.m
// ObjC Cocoa-specific code for Shoes.
//
#include "shoes/app.h"
#include "shoes/ruby.h"
#include "shoes/config.h"
#include "shoes/world.h"
#include "shoes/native.h"
#include "shoes/internal.h"
#include <Carbon/Carbon.h>

#define HEIGHT_PAD 10

#define INIT    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init]
#define RELEASE [pool release]

@implementation ShoesEvents
- (id)init
{
  return ((self = [super init]));
}
- (BOOL) application: (NSApplication *) anApplication
    openFile: (NSString *) aFileName
{
  shoes_load([aFileName UTF8String]);

  return YES;
}
@end

@implementation ShoesView
- (id)initWithFrame: (NSRect)frame andCanvas: (VALUE)c
{
  if ((self = [super initWithFrame: frame]))
  {
    canvas = c;
  }
  return self;
}
- (BOOL)isFlipped
{
  return YES;
}
- (void)drawRect: (NSRect)rect
{
  shoes_canvas *c;
  NSRect bounds = [self bounds];
  Data_Get_Struct(canvas, shoes_canvas, c);

  c->place.iw = c->place.w = c->width = bounds.size.width;
  c->place.ih = c->place.h = c->height = bounds.size.height;
  c->slot.context = (CGContextRef)[[NSGraphicsContext currentContext] graphicsPort];
  shoes_canvas_paint(canvas);
}
@end

@implementation ShoesButton
- (id)initWithFrame: (NSRect)frame andObject: (VALUE)o
{
  if ((self = [super initWithFrame: frame]))
  {
    object = o;
    [self setButtonType: NSMomentaryPushInButton];
    [self setBezelStyle: NSRoundedBezelStyle];
    [self setTarget: self];
    [self setAction: @selector(handleClick:)];
  }
  return self;
}
-(IBAction)handleClick: (id)sender
{
  shoes_control_send(object, s_click);
}
@end

@implementation ShoesTextField
- (id)initWithFrame: (NSRect)frame andObject: (VALUE)o isSecret: (BOOL)secret
{
  if ((self = [super initWithFrame: frame]))
  {
    object = o;
    // [[self cell] setEchosBullets: secret];
    [self setBezelStyle: NSRegularSquareBezelStyle];
    [self setTarget: self];
    [self setAction: @selector(handleChange:)];
  }
  return self;
}
-(IBAction)handleChange: (id)sender
{
  shoes_control_send(object, s_change);
}
@end

@implementation ShoesTextView
- (id)initWithFrame: (NSRect)frame andObject: (VALUE)o
{
  if ((self = [super initWithFrame: frame]))
  {
    object = o;
    textView = [[NSTextView alloc] initWithFrame:
      NSMakeRect(0, 0, frame.size.width, frame.size.height)];
    [textView setVerticallyResizable: YES];
    [textView setHorizontallyResizable: YES];
    
    [self setBorderType: NSBezelBorder];
    [self setHasVerticalScroller: YES];
    [self setHasHorizontalScroller: NO];
    [self setDocumentView: textView];
    // [self setTarget: self];
    // [self setAction: @selector(handleChange:)];
  }
  return self;
}
-(NSTextStorage *)textStorage
{
  return [textView textStorage];
}
-(IBAction)handleChange: (id)sender
{
  shoes_control_send(object, s_change);
}
@end

@implementation ShoesPopUpButton
- (id)initWithFrame: (NSRect)frame andObject: (VALUE)o
{
  if ((self = [super initWithFrame: frame pullsDown: NO]))
  {
    object = o;
    [self setTarget: self];
    [self setAction: @selector(handleChange:)];
  }
  return self;
}
-(IBAction)handleChange: (id)sender
{
  shoes_control_send(object, s_change);
}
@end

void shoes_native_init()
{
  INIT;
  NSApplication *NSApp = [NSApplication sharedApplication];
  shoes_world->os.events = [[ShoesEvents alloc] init];
  [NSApp setDelegate: shoes_world->os.events];
  RELEASE;
}

void shoes_native_cleanup(shoes_world_t *world)
{
  INIT;
  [shoes_world->os.events release];
  RELEASE;
}

void shoes_native_quit()
{
  INIT;
  NSApplication *NSApp = [NSApplication sharedApplication];
  [NSApp stop: nil];
  RELEASE;
}

void shoes_native_slot_mark(SHOES_SLOT_OS *slot)
{
  rb_gc_mark_maybe(slot->controls);
}

void shoes_native_slot_reset(SHOES_SLOT_OS *slot)
{
  slot->controls = rb_ary_new();
  rb_gc_register_address(&slot->controls);
}

void shoes_native_slot_clear(SHOES_SLOT_OS *slot)
{
  rb_ary_clear(slot->controls);
}

void shoes_native_slot_paint(SHOES_SLOT_OS *slot)
{
  [slot->view setNeedsDisplay: YES];
}

void shoes_native_slot_lengthen(SHOES_SLOT_OS *slot, int height, int endy)
{
}

void shoes_native_slot_scroll_top(SHOES_SLOT_OS *slot)
{
}

int shoes_native_slot_gutter(SHOES_SLOT_OS *slot)
{
  return 0;
}

void shoes_native_remove_item(SHOES_SLOT_OS *slot, VALUE item, char c)
{
}

shoes_code
shoes_app_cursor(shoes_app *app, ID cursor)
{
done:
  return SHOES_OK;
}

void
shoes_native_app_resized(shoes_app *app)
{
  NSRect rect = [app->os.window frame];
  rect.size.width = app->width;
  rect.size.height = app->height;
  [app->os.window setFrame: rect display: YES];
}

void
shoes_native_app_title(shoes_app *app, char *msg)
{
  [app->os.window setTitle: [NSString stringWithUTF8String: msg]];
}

shoes_code
shoes_native_app_open(shoes_app *app, char *path, int dialog)
{
  INIT;
  shoes_code code = SHOES_OK;

  app->os.window = [[NSWindow alloc] initWithContentRect: NSMakeRect(0, 0, app->width, app->height)
    styleMask: (NSTitledWindowMask | NSClosableWindowMask | NSMiniaturizableWindowMask | NSResizableWindowMask)
    backing: NSBackingStoreBuffered defer: NO];
  app->slot.view = [app->os.window contentView];
  RELEASE;

quit:
  return code;
}

void
shoes_native_app_show(shoes_app *app)
{
  [app->os.window orderFront: nil];
}

void
shoes_native_loop()
{
  NSApplication *NSApp = [NSApplication sharedApplication];
  [NSApp run];
}

void
shoes_native_app_close(shoes_app *app)
{
  [app->os.window close];
}

void
shoes_browser_open(char *url)
{
  VALUE browser = rb_str_new2("open ");
  rb_str_cat2(browser, url);
  shoes_sys(RSTRING_PTR(browser), 1);
}

void
shoes_slot_init(VALUE c, SHOES_SLOT_OS *parent, int x, int y, int width, int height, int scrolls, int toplevel)
{
  INIT;
  shoes_canvas *canvas;
  SHOES_SLOT_OS *slot;
  Data_Get_Struct(c, shoes_canvas, canvas);
  slot = &canvas->slot;

  slot->controls = parent->controls;
  slot->view = [[ShoesView alloc] initWithFrame: NSMakeRect(x, y, width, height) andCanvas: c];
  [slot->view setAutoresizesSubviews: NO];
  if (toplevel)
    [slot->view setAutoresizingMask: (NSViewWidthSizable | NSViewHeightSizable)];
  [parent->view addSubview: slot->view];
  RELEASE;
}

cairo_t *
shoes_cairo_create(shoes_canvas *canvas)
{
  canvas->slot.surface = cairo_quartz_surface_create_for_cg_context(canvas->slot.context,
    canvas->width, canvas->height);
  return cairo_create(canvas->slot.surface);
}

void shoes_cairo_destroy(shoes_canvas *canvas)
{
  cairo_surface_destroy(canvas->slot.surface);
}

void
shoes_group_clear(SHOES_GROUP_OS *group)
{
}

void
shoes_native_canvas_place(shoes_canvas *self_t, shoes_canvas *pc)
{
  NSRect rect, rect2;
  rect.origin.x = (self_t->place.ix + self_t->place.dx) * 1.;
  rect.origin.y = ((self_t->place.iy + self_t->place.dy) * 1.) + 4;
  rect.size.width = (self_t->place.iw * 1.) + 4;
  rect.size.height = (self_t->place.ih * 1.) - 8;
  rect2 = [self_t->slot.view frame];
  if (rect.origin.x != rect2.origin.x || rect.origin.y != rect2.origin.y ||
      rect.size.width != rect2.size.width || rect.size.height != rect2.size.height)
  {
    [self_t->slot.view setFrame: rect];
  }
}

void
shoes_native_canvas_resize(shoes_canvas *canvas)
{
  NSSize size = {canvas->width, canvas->height};
  [canvas->slot.view setFrameSize: size];
}

void
shoes_native_control_hide(SHOES_CONTROL_REF ref)
{
  [ref setHidden: YES];
}

void
shoes_native_control_show(SHOES_CONTROL_REF ref)
{
  [ref setHidden: NO];
}

static void
shoes_native_control_frame(SHOES_CONTROL_REF ref, shoes_place *p)
{
  NSRect rect;
  rect.origin.x = p->ix + p->dx; rect.origin.y = p->iy + p->dy;
  rect.size.width = p->iw; rect.size.height = p->ih;
  [ref setFrame: rect];
}

void
shoes_native_control_position(SHOES_CONTROL_REF ref, shoes_place *p1, VALUE self,
  shoes_canvas *canvas, shoes_place *p2)
{
  PLACE_COORDS();
  [canvas->slot.view addSubview: ref];
  shoes_native_control_frame(ref, p2);
  rb_ary_push(canvas->slot.controls, self);
}

void
shoes_native_control_repaint(SHOES_CONTROL_REF ref, shoes_place *p1,
  shoes_canvas *canvas, shoes_place *p2)
{
  if (CHANGED_COORDS()) {
    PLACE_COORDS();
    shoes_native_control_frame(ref, p2);
  }
}

void
shoes_native_control_focus(SHOES_CONTROL_REF ref)
{
}

void
shoes_native_control_remove(SHOES_CONTROL_REF ref, shoes_canvas *canvas)
{
}

void
shoes_native_control_free(SHOES_CONTROL_REF ref)
{
}

SHOES_CONTROL_REF
shoes_native_surface_new(shoes_canvas *canvas, VALUE self, shoes_place *place)
{
  return NULL;
}

void
shoes_native_surface_position(SHOES_CONTROL_REF ref, shoes_place *p1, 
  VALUE self, shoes_canvas *canvas, shoes_place *p2)
{
  PLACE_COORDS();
}

void
shoes_native_surface_remove(shoes_canvas *canvas, SHOES_CONTROL_REF ref)
{
}

SHOES_CONTROL_REF
shoes_native_button(VALUE self, shoes_canvas *canvas, shoes_place *place, char *msg)
{
  INIT;
  ShoesButton *button = [[ShoesButton alloc] initWithFrame: 
    NSMakeRect(place->ix + place->dx, place->iy + place->dy, 
    place->ix + place->dx + place->iw, place->iy + place->dy + place->ih)
    andObject: self];
  [button setTitle: [NSString stringWithUTF8String: msg]];
  RELEASE;
  return (NSControl *)button;
}

SHOES_CONTROL_REF
shoes_native_edit_line(VALUE self, shoes_canvas *canvas, shoes_place *place, VALUE attr, char *msg)
{
  INIT;
  ShoesTextField *field = [[ShoesTextField alloc] initWithFrame:
    NSMakeRect(place->ix + place->dx, place->iy + place->dy,
    place->ix + place->dx + place->iw, place->iy + place->dy + place->ih)
    andObject: self isSecret:(RTEST(ATTR(attr, secret)) ? YES : NO)];
  [field setStringValue: [NSString stringWithUTF8String: msg]];
  [field setEditable: YES];
  RELEASE;
  return (NSControl *)field;
}

VALUE
shoes_native_edit_line_get_text(SHOES_CONTROL_REF ref)
{
  VALUE text = Qnil;
  INIT;
  text = rb_str_new2([[ref stringValue] UTF8String]);
  RELEASE;
  return text;
}

void
shoes_native_edit_line_set_text(SHOES_CONTROL_REF ref, char *msg)
{
  INIT;
  [ref setStringValue: [NSString stringWithUTF8String: msg]];
  RELEASE;
}

SHOES_CONTROL_REF
shoes_native_edit_box(VALUE self, shoes_canvas *canvas, shoes_place *place, VALUE attr, char *msg)
{
  INIT;
  ShoesTextView *tv = [[ShoesTextView alloc] initWithFrame:
    NSMakeRect(place->ix + place->dx, place->iy + place->dy,
    place->ix + place->dx + place->iw, place->iy + place->dy + place->ih)
    andObject: self];
  shoes_native_edit_box_set_text((NSControl *)tv, msg);
  RELEASE;
  return (NSControl *)tv;
}

VALUE
shoes_native_edit_box_get_text(SHOES_CONTROL_REF ref)
{
  VALUE text = Qnil;
  INIT;
  text = rb_str_new2([[[(ShoesTextView *)ref textStorage] string] UTF8String]);
  RELEASE;
  return text;
}

void
shoes_native_edit_box_set_text(SHOES_CONTROL_REF ref, char *msg)
{
  INIT;
  [[[(ShoesTextView *)ref textStorage] mutableString] setString: [NSString stringWithUTF8String: msg]];
  RELEASE;
}

SHOES_CONTROL_REF
shoes_native_list_box(VALUE self, shoes_canvas *canvas, shoes_place *place, VALUE attr, char *msg)
{
  INIT;
  ShoesPopUpButton *pop = [[ShoesPopUpButton alloc] initWithFrame:
    NSMakeRect(place->ix + place->dx, place->iy + place->dy,
    place->ix + place->dx + place->iw, place->iy + place->dy + place->ih)
    andObject: self];
  RELEASE;
  return (NSControl *)pop;
}

void
shoes_native_list_box_update(SHOES_CONTROL_REF ref, VALUE ary)
{
  INIT;
  long i;
  ShoesPopUpButton *pop = (ShoesPopUpButton *)ref;
  [pop removeAllItems];
  for (i = 0; i < RARRAY_LEN(ary); i++)
  {
    char *msg = RSTRING_PTR(rb_ary_entry(ary, i));
    [[pop menu] insertItemWithTitle: [NSString stringWithUTF8String: msg] action: nil
      keyEquivalent: @"" atIndex: i];
  }
  RELEASE;
}

VALUE
shoes_native_list_box_get_active(SHOES_CONTROL_REF ref, VALUE items)
{
  int sel = [(ShoesPopUpButton *)ref indexOfSelectedItem];
  if (sel >= 0)
    return rb_ary_entry(items, sel);
  return Qnil;
}

void
shoes_native_list_box_set_active(SHOES_CONTROL_REF ref, VALUE ary, VALUE item)
{
  int idx = rb_ary_index_of(ary, item);
  if (idx < 0) return;
  [(ShoesPopUpButton *)ref selectItemAtIndex: idx];
}

SHOES_CONTROL_REF
shoes_native_progress(VALUE self, shoes_canvas *canvas, shoes_place *place, VALUE attr, char *msg)
{
  return NULL;
}

double
shoes_native_progress_get_fraction(SHOES_CONTROL_REF ref)
{
  return 0.0;
}

void
shoes_native_progress_set_fraction(SHOES_CONTROL_REF ref, double perc)
{
}

SHOES_CONTROL_REF
shoes_native_check(VALUE self, shoes_canvas *canvas, shoes_place *place, VALUE attr, char *msg)
{
  return NULL;
}

VALUE
shoes_native_check_get(SHOES_CONTROL_REF ref)
{
  return Qfalse;
}

void
shoes_native_check_set(SHOES_CONTROL_REF ref, int on)
{
}

SHOES_CONTROL_REF
shoes_native_radio(VALUE self, shoes_canvas *canvas, shoes_place *place, VALUE attr, char *msg)
{
  return NULL;
}

void
shoes_native_timer_remove(shoes_canvas *canvas, SHOES_TIMER_REF ref)
{
}

SHOES_TIMER_REF
shoes_native_timer_start(VALUE self, shoes_canvas *canvas, unsigned int interval)
{
  return NULL;
}

VALUE
shoes_native_clipboard_get(shoes_app *app)
{
  return Qnil;
}

void
shoes_native_clipboard_set(shoes_app *app, VALUE string)
{
}

VALUE
shoes_native_window_color(shoes_app *app)
{
  return Qnil;
}

VALUE
shoes_native_dialog_color(shoes_app *app)
{
  return Qnil;
}

VALUE
shoes_dialog_alert(VALUE self, VALUE msg)
{
  INIT;
  VALUE answer = Qnil;
  NSAlert *alert = [NSAlert alertWithMessageText: nil
    defaultButton: @"OK" alternateButton: nil otherButton: nil 
    informativeTextWithFormat: [NSString stringWithUTF8String: RSTRING_PTR(msg)]];
  [alert runModal];
  RELEASE;
  return Qnil;
}

VALUE
shoes_dialog_ask(VALUE self, VALUE quiz)
{
  return Qnil;
}

VALUE
shoes_dialog_confirm(VALUE self, VALUE quiz)
{
  INIT;
  VALUE answer = Qnil;
  char *msg = RSTRING_PTR(quiz);
  NSAlert *alert = [NSAlert alertWithMessageText: nil
    defaultButton: @"OK" alternateButton: @"Cancel" otherButton:nil 
    informativeTextWithFormat: [NSString stringWithUTF8String: msg]];
  answer = ([alert runModal] == NSAlertFirstButtonReturn ? Qtrue : Qfalse);
  RELEASE;
  return Qnil;
}

VALUE
shoes_dialog_color(VALUE self, VALUE title)
{
  Point where;
  RGBColor colwh = { 0xFFFF, 0xFFFF, 0xFFFF };
  RGBColor _color;
  VALUE color = Qnil;
  GLOBAL_APP(app);

  where.h = where.v = 0;
  if (GetColor(where, RSTRING_PTR(title), &colwh, &_color))
  {
    color = shoes_color_new(_color.red/256, _color.green/256, _color.blue/256, SHOES_COLOR_OPAQUE);
  }
  return color;
}

VALUE
shoes_dialog_open(VALUE self)
{
  NSOpenPanel* openDlg = [NSOpenPanel openPanel];
  [openDlg setCanChooseFiles:YES];
  [openDlg setCanChooseDirectories:NO];
  [openDlg setAllowsMultipleSelection:NO];
  if ( [openDlg runModalForDirectory:nil file:nil] == NSOKButton )
  {
    NSArray* files = [openDlg filenames];
    char *filename = [[files objectAtIndex: 0] UTF8String];
    return rb_str_new2(filename);
  }
  return Qnil;
}

VALUE
shoes_dialog_save(VALUE self)
{
  NSSavePanel* saveDlg = [NSSavePanel savePanel];
  if ( [saveDlg runModalForDirectory:nil file:nil] == NSOKButton )
  {
    char *filename = [[saveDlg filename] UTF8String];
    return rb_str_new2(filename);
  }
  return Qnil;
}
