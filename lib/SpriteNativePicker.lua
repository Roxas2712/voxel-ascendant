-- Use the engine's declared optional-import picker, as Stadium uses its ROM bridge.
-- Never scan or consume an unrelated ROM selection. The pinned package importer
-- remains the only code that can activate the selected data.
local M={}
function M.new(d)
  local self={};local selected='ascendant-sprite-import.pack'
  function self:open()
    local ok,Importer=pcall(require,'src.import.RomImporter')
    if not ok or type(Importer.chooseRequiredImport)~='function' then return false,'native_import_picker_unavailable'end
    local raw=d.mod:read('manifest.json');local manifest=d.decode(raw)
    local declared=false
    for _,spec in ipairs(manifest.optional_imports or {})do if spec.id=='ascendant_sprite_package' and spec.file==selected then declared=true end end
    if not declared then return false,'optional_sprite_import_not_declared'end
    manifest.path=d.mod.path
    -- Avoid touching files belonging to a launcher/Stadium picker already in flight.
    for _,path in ipairs({'picked_rom.gb','picked_required_import.bin','picked_stadium.z64'})do
      if d.fs.getInfo(path,'file')then return false,'another_import_is_pending'end
    end
    local target=manifest.path..'/baseroms/'..selected
    if d.fs.getInfo(target,'file') and not d.fs.remove(target)then return false,'import_staging_busy'end
    local picker={mods={{id=d.mod.id,manifest=manifest}},nativePicker=true,mobileFileBridge=true,android=true,isNX=false}
    local called,err=pcall(Importer.chooseRequiredImport,picker,d.mod.id,'ascendant_sprite_package')
    if not called or not picker.pickerPendingKind then return false,picker.requiredImportNotice and picker.requiredImportNotice.text or 'native_picker_unavailable'end
    self.picker=picker;self.target=target;self.pending=true;self.lastSize=nil;self.stable=0
    return true
  end
  function self:poll(dt)
    if not self.pending then return end
    local candidates={self.target,'picked_required_import.bin'}
    if self.picker.requiredImportLegacyRomPick then candidates[#candidates+1]='picked_rom.gb'end
    for _,path in ipairs(candidates)do
      local info=d.fs.getInfo(path,'file')
      if info and info.size>0 then
        if info.size==self.lastSize then self.stable=self.stable+(dt or 0)else self.stable=0;self.lastSize=info.size end
        -- Allow the native bridge to finish its staging write; the sequential
        -- importer rejects incomplete bytes and never executes the picked file.
        if self.stable>=1 then self.pending=false;return path end
        return
      end
    end
  end
  return self
end
return M
