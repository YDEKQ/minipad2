unit UDeleteHandler;

interface

uses UPageSuper, UxlClasses;

type
	TDeleteHandler = class
   private
      FRecycleBin: TPageSuper;
   public
      procedure SetRecycleBin (value: TPageSuper);

      procedure Remove (value, parent: TPageSuper);
      function CanRemove (value, parent: TPageSuper; var b_delete: boolean): boolean;   // b_delete ���ھ����˵���Ŀ�ǡ�ɾ�������ǡ��Ƴ���
   end;

function DeleteHandler(): TDeleteHandler;

implementation

uses UGlobalObj, UOptionManager, UPageStore, UPageFactory, UTypeDef;

var FDeleteHandler: TDeleteHandler;

function DeleteHandler(): TDeleteHandler;
begin
	if FDeleteHandler = nil then
   	FDeleteHandler := TDeleteHandler.Create;
   result := FDeleteHandler;
end;

procedure TDeleteHandler.SetRecycleBin (value: TPageSuper);
begin
	FRecycleBin := value;
end;

procedure TDeleteHandler.Remove (value, parent: TPageSuper);
var b_delete: boolean;
	i, n, id: integer;
begin
	if not CanRemove (value, parent, b_delete) then exit;

   if parent.Childs <> nil then
   	parent.Childs.RemoveChild (value.id)
   else
   	PageCenter.EventNotify (pctRemoveChild, parent.id, value.id);
   if b_delete then
   begin
      if (FRecycleBin = nil) or (value.owner = FRecycleBin) or (not FRecycleBin.CanAddChild (value.pagetype)) then
      	value.Delete
      else
      begin
      	if parent <> value.owner then   // ���searchpage������������������Ŀ��ҳ��
         	value.owner.childs.RemoveChild (value.id);
         PageStore.GetFirstPageId (ptFavorite, id);
         PageStore[id].Childs.RemoveChild (value.id);
         value.Owner := FRecycleBin;
         FRecycleBin.Childs.AddChild (value.id);

         n := FRecycleBin.Childs.Count;
         if (OptionMan.Options.RecyclerLimit >= 0) and (n > OptionMan.Options.RecyclerLimit) then
         	for i := n - OptionMan.Options.RecyclerLimit -1 downto 0 do
            begin
            	id := FRecycleBin.Childs.ChildId (i);
            	FRecycleBin.Childs.RemoveChild (id);
            	PageStore[id].delete;
            end;
      end;
   end;
end;

function TDeleteHandler.CanRemove (value, parent: TPageSuper; var b_delete: boolean): boolean;
begin
   b_delete := false;
	if parent.isvirtualcontainer then   // �ղؼ��е����������κ�����¶���ɾ��
   	result := true
   else
   begin
      result := false;
      if value = nil then exit;
      if not value.CanDelete then exit;

      result := true;
      b_delete := not value.SingleInstance;
   end;
end;

//------------

initialization

finalization
	FDeleteHandler.free;

end.

//   	FRemoveOnly: array of TPageSuper;
//      FNoRemovables: array of TPageSuper;

//      procedure AddRemoveOnly (value: TPageSuper);     // ֻ�Ƴ���ɾ��
//      procedure AddNoRemovable (value: TPageSuper);   // �����Ƴ�

//procedure TDeleteHandler.AddRemoveOnly (value: TPageSuper);
//var n: integer;
//begin
//   n := Length (FRemoveOnly);
//   SetLength (FRemoveOnly, n + 1);
//   FRemoveOnly[n] := value;
//end;
//
//procedure TDeleteHandler.AddNoRemovable (value: TPageSuper);
//var n: integer;
//begin
//   n := Length (FNoRemovables);
//   SetLength (FNoRemovables, n + 1);
//   FNoRemovables[n] := value;
//end;


