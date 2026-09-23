package com.mobiwire.printraw;

// Interface du service système com.mobiwire.printraw (terminal MobiWire
// MP3+), reconstruite par désassemblage de son onTransact. L'ORDRE des
// méthodes fixe les codes de transaction Binder et doit rester identique à
// l'original : 1 = powerOn, 2 = transmit, 3 = getPowerState. Le package et
// le nom de l'interface servent de jeton Binder et ne doivent pas changer.
interface PrintIOInterface {
    boolean powerOn(boolean on);
    byte[] transmit(in byte[] data, int length);
    boolean getPowerState();
}
