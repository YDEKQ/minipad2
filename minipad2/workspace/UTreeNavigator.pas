unit UTreeNavigator;

interface

uses windows, Messages, CommCtrl, UxlWinControl, UxlDragControl, UNavigatorSuper, UxlTreeView, UxlMiscCtrls, UxlExtClasses,
	UPageSuper;

type TTreeNavigator = class (TNavigatorSuper, IOptionObserver)
private
   FTree: TxlTreeView;
   FCurrentPage: TPageSuper;
   FDisableSelChangeMessage: boolean;

   function Page (h: HTreeItem): TPageSuper;
	function f_FindItem (value: TPageSuper): HTreeItem;
	function f_GetTreeItem (o_page: TPageSuper): TTreeViewItem;
   function f_OnTreeSelChanging (oldhandle, newhandle: HTreeItem): integer;
	function f_OnTreeBeginLabelEdit (handle: HTreeItem; const newtext: widestring): integer;
   function f_OnTreeEndLabelEdit (handle: HTreeItem; const newtext: widestring): integer;
   procedure f_OnTreeContextMenu (handle: HTreeItem);
   procedure f_OnTreeItemFirstExpanding (h: HTreeItem);
   procedure f_OnTreeItemDropEvent (o_dragsource: IDragSource; hidxTarget: integer; b_copy: boolean);
   function f_ProcessTreeMessage (AMessage, wParam, lParam: DWORD; var b_processed: boolean): DWORD;
	procedure f_PopulateChildNodes (hParent: HTreeItem);
protected
   procedure LoadIndex (); override;
   procedure SelectPage (value: TPageSuper); override;
	procedure AddPage (value: TPageSuper); override;
   procedure ResetPage (value: TPageSuper); override;
   procedure DeletePage (value: TPageSuper); override;
   procedure RenamePage (value: TPageSuper); override;
public
	constructor Create (WndParent: TxlWinContainer);
   destructor Destroy (); override;
   function Control (): TxlDragControl; override;

   procedure Optionchanged ();
end;

implementation

uses Resource, UGlobalObj, UxlList, UxlClasses, UxlCommDlgs, UxlWindow, UxlWinDef, UxlStrUtils, UPageStore, UPageFactory,
	UOptionManager, UTypeDef;

constructor TTreeNavigator.Create (WndParent: TxlWinContainer);
begin
   FTree := TxlTreeView.create (WndParent);
   with FTree do
   begin
      Images := PageImageList.Images;

      CanDrag := true;
      CanDrop := true;

      Items.OnSelChanging := f_OnTreeSelChanging;
      Items.OnBeginLabelEdit := f_OnTreeBeginLabelEdit;
      Items.OnEndLabelEdit := f_OnTreeEndLabelEdit;
      OnContextMenu := f_OnTreeContextMenu;
      Items.OnFirstExpanding := f_OnTreeItemFirstExpanding;
      OnDropEvent := f_OnTreeItemDropEvent;
      MessageHandler := f_ProcessTreeMessage;
   end;

   OptionMan.AddObserver(self);
end;

destructor TTreeNavigator.Destroy ();
begin
   OptionMan.RemoveObserver(self);
   FTree.free;
   inherited;
end;

function TTreeNavigator.Control (): TxlDragControl;
begin
	result := FTree;
end;

procedure TTreeNavigator.Optionchanged ();
var o_tvstyle: TTreeViewStyle;
begin
	FTree.Font := OptionMan.Options.TreeFont;
   FTree.Color := OptionMan.Options.TreeColor;

   with o_tvstyle do
   begin
   	EditLabels := true;
   	NoHScroll := not OptionMan.Options.TreeHorzScroll;
      HasButtons := OptionMan.Options.NodeButtons;
      HasLines := OptionMan.Options.NodeLines;
   	LinesAtRoot := OptionMan.Options.LinesAtRoot;
   end;
   FTree.Style := o_tvstyle;

   if OptionMan.Options.ShowNodeImages <> FTree.ShowImages then
   begin
   	FTree.ShowImages := OptionMan.Options.ShowNodeImages;
      if Active then
      begin
         LoadIndex ();
         SelectPage (FCurrentPage);
      end;
   end;
end;

//--------------------

procedure TTreeNavigator.LoadIndex ();
begin
	FDisableSelChangeMessage := true;   // ���� Items.Clear ������ SelChanging �¼�
   FTree.Items.Clear;
   f_PopulateChildNodes (nil);
	FDisableSelChangeMessage := false;
end;

function TTreeNavigator.Page (h: HTreeItem): TPageSuper;
var id: integer;
begin
	if h = nil then
   	result := Root
   else
   begin
      id := FTree.Items[h].data;
      result := PageStore[id];
   end;
end;

procedure TTreeNavigator.f_PopulateChildNodes (hParent: HTreeItem);
var o_page: TPageSuper;
	o_list: TxlIntList;
   i: integer;
	o_item: TTreeViewItem;
begin
	if hParent = nil then
      o_page := Root
   else
   	o_page := Page(hParent);

   o_list := TxlIntList.Create;
   o_page.GetChildList (o_list);
   for i := o_list.Low to o_list.High do
   begin
   	o_item := f_GetTreeItem (PageStore[o_list[i]]);
   	FTree.Items.AddChild (hParent, o_item);
	end;
   o_list.free;
end;

function TTreeNavigator.f_GetTreeItem (o_page: TPageSuper): TTreeViewItem;
begin
	with result do
   begin
   	if FTree.ShowImages then
      	text := o_page.name
      else
      	text := f_NameToLabel (o_page);
      data := o_page.id;
     	image := o_page.ImageIndex;
      selectedimage := image;
      state := 0;
      children := (o_page.Childs <> nil) and (o_page.Childs.HasChildInTree);
   end;
end;

procedure TTreeNavigator.SelectPage (value: TPageSuper);
var h: HTreeItem;
begin
	h := f_FindItem(value);
	if h <> nil then
   begin
   	FTree.Items.Select (h, false);
      FCurrentPage := value;
   end;
end;

function TTreeNavigator.f_FindItem (value: TPageSuper): HTreeItem;
	function f_FindFrom (hParent: HTreeItem; o_list: TxlObjList; i_depth: integer): HTreeItem;  // ��㶨λ
   var h: HTreeItem;
   begin
   	if hParent <> nil then
      begin
      	FTree.Items.Expand (hParent);
      	h := FTree.Items.Find (fmChildItem, hParent);
      end
      else
      	h := FTree.Items.Find (fmRootItem);
      while (h <> nil) and (Page(h) <> TPageSuper(o_list[i_depth])) do
      	h := FTree.Items.Find (fmNextItem, h);
      if h = nil then
      	result := nil
      else if i_depth < o_list.High then
      	result := f_FindFrom (h, o_list, i_depth + 1)
      else
      	result := h;
   end;
var o_list: TxlObjList;
	p: TPageSuper;
begin
	result := nil;
	if value = nil then exit;

   // Get Ancestors
   o_list := TxlObjList.Create;
   o_list.Add (value);
   p := value.Owner;
   while p <> nil do
   begin
   	o_list.InsertFirst (p);
      if p.Owner = p then exit; // ��ֹ��ѭ��
      p := p.Owner;
   end;

   result := f_FindFrom (nil, o_list, o_list.low + 1);
   o_list.Free;
end;

procedure TTreeNavigator.AddPage (value: TPageSuper);
   procedure f_AddChildNode (hOwner: HTREEITEM; o_page: TPageSuper);
   var o_item: TTreeViewItem;
      h: HTreeItem;
      o_list: TxlIntList;
      i: integer;
   begin
      o_item := f_GetTreeItem (o_page);
      o_list := TxlIntList.Create;
      Page(hOwner).GetChildList (o_list);
      h := nil;
      for i := o_list.High downto o_list.Low do
         if o_list[i] = o_page.id then
         begin
            if h = nil then
               FTree.Items.AddChild (hOwner, o_item)
            else
               FTree.Items.InsertBefore(h, o_item);
            break;
         end
         else if h = nil then
            h := f_FindItem (PageStore[o_list[i]])
         else
            h := FTree.Items.Find (fmPreviousItem, h);
      o_list.free;
   end;
var h: HTreeItem;
	o_item: TTreeViewItem;
begin
	h := f_FindItem (value.Owner);
   if h <> nil then
   begin
      o_item := FTree.Items[h];
      o_item.Children := true;
      FTree.Items[h] := o_item;
      FTree.Items.Expand (h);
   end;
   if f_FindItem (value) = nil then
   	f_AddChildNode (h, value);
end;

procedure TTreeNavigator.ResetPage (value: TPageSuper);
var h: HTreeItem;
begin
   h := f_FindItem (value);
   if h <> nil then
   	FTree.Items[h] := f_GetTreeItem (value);
end;

procedure TTreeNavigator.RenamePage (value: TPageSuper);
var h: HTreeItem;
begin
	h := f_FindItem (value);
   if h <> nil then
   	FTree.Items.EditLabel (h);
end;

procedure TTreeNavigator.DeletePage (value: TPageSuper);
var h: HTreeItem;
begin
	h := f_FindItem (value);
   if h <> nil then
   	FTree.Items.Delete (h, false);
end;

//-------------------

function TTreeNavigator.f_OnTreeSelChanging (oldhandle, newhandle: HTreeItem): integer;
begin
	if (oldhandle <> newhandle) and (not FDisableSelChangeMessage) then
   	PageCenter.ActivePage := Page(newhandle);
   result := 0;
end;

function TTreeNavigator.f_OnTreeBeginLabelEdit (handle: HTreeItem; const newtext: widestring): integer;
var h_edit: HWND;
	s_label: widestring;
begin
   result := 0;
   if FTree.ShowImages then exit;
   h_edit := FTree.Perform (TVM_GETEDITCONTROL, 0, 0);
   if h_edit = 0 then exit;
   s_label := Page(handle).name;
   SetWindowTextW (h_edit, pwidechar(s_label));
   SendMessageW (h_edit, EM_SETSEL, 0, -1);
end;

function TTreeNavigator.f_OnTreeEndLabelEdit (handle: HTreeItem; const newtext: widestring): integer;
begin
   if newtext <> '' then
   begin
   	Page(handle).name := MultiLineToSingleLine (newtext, true);
      result := 1;    // accept change
      EventMan.EventNotify (e_PageNameChanged, Page(handle).id);
   end
   else
   	result := 0;
end;

procedure TTreeNavigator.f_OnTreeContextMenu (handle: HTreeItem);
var p: TPageSuper;
	i_context: integer;
begin
	p := Page(handle);
	if (p <> nil) and (p <> PageCenter.ActivePage) then
      PageCenter.ActivePage := p
	else
   	p := PageCenter.ActivePage;
   case p.PageType of
   	ptSearch:
      	i_context := SearchContext;
      ptRecycleBin:
      	i_context := RecycleBinContext;
      ptRecentModify, ptRecentCreate, ptRecentVisit:
      	i_context := RecentPagesContext;
      ptRecentRoot, ptTemplate, ptFavorite, ptClip, ptFastLink:
      	i_context := SysPageContext;
      else
      	i_context := PageContext;
   end;
	EventMan.EventNotify (e_ContextMenuDemand, i_context);
end;

procedure TTreeNavigator.f_OnTreeItemFirstExpanding (h: HTreeItem);
begin
	f_PopulateChildNodes (h);
end;

procedure TTreeNavigator.f_OnTreeItemDropEvent (o_dragsource: IDragSource; hidxTarget: integer; b_copy: boolean);
var o_page: TPageSuper;
begin
   if (hidxTarget >= 0) and assigned (OnDropItems) then
   begin
   	o_page := Page(HTreeItem(hidxTarget));
   	OnDropItems (o_dragsource, o_page.id, o_page.Owner.id, b_copy);
   end;
end;

function TTreeNavigator.f_ProcessTreeMessage (AMessage, wParam, lParam: DWORD; var b_processed: boolean): DWord;
begin
	case AMessage of
      WM_MBUTTONUP:
      	begin
         	if OptionMan.Options.PageMButtonClick = pbDelete then
            	CommandMan.ExecuteCommand(m_deletepage)
            else
            	CommandMan.ExecuteCommand(m_switchLock);
            result := 0;
            b_processed := true;
         end;
      else
         b_processed := false;
   end;
end;

end.







