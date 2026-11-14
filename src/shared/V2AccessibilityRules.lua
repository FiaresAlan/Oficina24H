--!strict
-- V2-15: preferências acessíveis, triviais e idempotentes.
-- Não interferem em tempo do servidor, qualidade, dinheiro ou OS.
local R={}
R.Keys={
    DriveHaptics=true, -- vibração é opcional e o texto sempre existe
    DriveSfx=true, -- áudio cosmético, não obrigatório para diagnosticar
    LowDetail=false, -- reduz pedestres/carros ambientais locais
}
function R.New():any
    return {DriveHaptics=true,DriveSfx=true,LowDetail=false}
end
function R.Sanitize(source:any):any
    local v=type(source)=="table" and source or {}
    return {
        DriveHaptics=type(v.DriveHaptics)=="boolean"
            and v.DriveHaptics or true,
        DriveSfx=type(v.DriveSfx)=="boolean" and v.DriveSfx or true,
        LowDetail=v.LowDetail==true,
    }
end
function R.Set(raw:any,key:any,value:any):(any?,string)
    if type(key)~="string" or R.Keys[key]==nil
        or type(value)~="boolean" then
        return nil,"Preferência inválida."
    end
    local state=R.Sanitize(raw)
    state[key]=value
    return state,"Preferência atualizada."
end
return R
