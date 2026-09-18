-- UI wording only. Internal diagnostic codes and persisted state stay intact.
local M={}
local messages={
 bundled_inventory_checking={'Existing sprite files are being checked. Please wait.','Vorhandene Sprite-Dateien werden geprueft. Bitte warten.'},
 bundled_removal_pending={'An external removal request is pending. Close the game and use manage-sprites.py from the update bundle.','Ein externer Loeschauftrag wartet. Spiel schliessen und manage-sprites.py aus dem Updatepaket verwenden.'},
 bundled_removal_cancelled={'Removal request cancelled. Existing sprite files remain unchanged.','Loeschauftrag abgebrochen. Vorhandene Sprite-Dateien bleiben unveraendert.'},
 invalid_bundled_removal_request={'The saved removal request is invalid. No built-in files were removed.','Der gespeicherte Loeschauftrag ist ungueltig. Keine eingebauten Dateien wurden entfernt.'},
 not_yet_available={'This package is not available yet.','Dieses Paket ist noch nicht verfügbar.'},
 busy_or_restart_required={'Finish the current operation or restart the game first.','Bitte zuerst den laufenden Vorgang beenden oder das Spiel neu starten.'},
 busy={'Another operation is still running.','Ein anderer Vorgang läuft noch.'},
 cancelled={'Cancelled. Downloaded parts are kept.','Abgebrochen. Geladene Teile bleiben erhalten.'},
 selection_cancelled={'No file selected.','Keine Datei ausgewählt.'},
 choose_package_file={'Choose a package file. It will be verified before installation.','Paketdatei auswählen. Sie wird vor der Installation geprüft.'},
 importer_unavailable={'The file importer is unavailable.','Der Dateiimport ist nicht verfügbar.'},
 link_card_unavailable={'The download link could not be displayed.','Der Downloadlink konnte nicht angezeigt werden.'},
 file_copy_failed={'The selected file could not be copied. Check free space and access.','Die gewählte Datei konnte nicht kopiert werden. Speicherplatz und Zugriff prüfen.'},
 file_open_failed={'The selected file could not be opened.','Die gewählte Datei konnte nicht geöffnet werden.'},
 file_size_invalid={'The selected file is empty or too large.','Die gewählte Datei ist leer oder zu groß.'},
 cache_write_failed={'Saving failed. Check free space and access, then retry.','Speichern fehlgeschlagen. Speicherplatz und Zugriff prüfen, dann erneut versuchen.'},
 inventory_incomplete={'Installed files could not be fully checked. Nothing was removed.','Installierte Dateien konnten nicht vollständig geprüft werden. Nichts wurde entfernt.'},
 restart_required={'Verified. Restart the game to activate the content.','Geprüft. Zum Aktivieren bitte das Spiel neu starten.'},
 sprite_restart_required={'Restart the game to activate the verified sprites.','Zum Aktivieren der geprüften Sprites bitte das Spiel neu starten.'},
 sprite_download_pending={'The required sprites are being downloaded.','Die benötigten Sprites werden heruntergeladen.'},
 package_mismatch={'This file does not match the selected package.','Diese Datei passt nicht zum ausgewählten Paket.'},
 hash_mismatch={'The file failed verification. Download it again.','Die Datei hat die Prüfung nicht bestanden. Bitte erneut herunterladen.'},
 size_mismatch={'The download is incomplete. Please retry.','Der Download ist unvollständig. Bitte erneut versuchen.'},
 incomplete_package={'The package is incomplete. Please retry.','Das Paket ist unvollständig. Bitte erneut versuchen.'},
 package_not_published={'This package is not available yet.','Dieses Paket ist noch nicht verfügbar.'},
 no_published_mirrors={'No download source is currently available.','Aktuell ist keine Downloadquelle verfügbar.'},
 request_failed={'The download failed. Please retry or use file import.','Der Download ist fehlgeschlagen. Erneut versuchen oder Dateiimport nutzen.'},
 timeout={'The download timed out. Please retry.','Der Download hat zu lange gedauert. Bitte erneut versuchen.'},
 report_pending_retry={'Report queued for another attempt.','Bericht wartet auf einen erneuten Versuch.'},
 report_endpoint_not_configured={'Automatic reports are unavailable.','Automatische Berichte sind nicht verfügbar.'},
 diagnostic_write_failed={'The local report could not be saved.','Der lokale Bericht konnte nicht gespeichert werden.'},
}
local states={idle={'READY','BEREIT'},downloading={'DOWNLOADING','LÄDT'},importing={'IMPORTING','IMPORTIERT'},ready={'VERIFIED','GEPRÜFT'},error={'FAILED','FEHLER'},cancelled={'CANCELLED','ABGEBROCHEN'}}
function M.message(code,de)
 local text=tostring(code or '');local row=messages[text]
 if row then return row[de and 2 or 1]end
 if text:match('^[a-z][a-z0-9_]*_[a-z0-9_]+$')then
  return de and 'Vorgang fehlgeschlagen. Details stehen im Diagnosebericht.' or 'The operation failed. See the diagnostic report for details.'
 end
 return text
end
function M.state(code,de)local row=states[code];return row and row[de and 2 or 1]or M.message(code,de)end
return M
