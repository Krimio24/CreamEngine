package funkin.modding;

class ModMain {
    public var modName:String;

    public function new(name:String, ?onInit:Void->Void) {
        this.modName = name;
        if (onInit != null) {
            onInit();
        }
    }
}
