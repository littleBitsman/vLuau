use std::fs::{File, read_to_string};

use rbx_binary::to_writer;
use rbx_dom_weak::{InstanceBuilder, WeakDom};

fn module_script_with_source(name: &str, source: String) -> InstanceBuilder {
    InstanceBuilder::new("ModuleScript")
        .with_name(name)
        .with_property("Source", source)
}

fn main() {
    let license = {
        let license = read_to_string("LICENSE").expect("Failed to read LICENSE file");
        let mut final_license = String::with_capacity(license.len() + 80);
        final_license.push_str("--[[\n");
        final_license.push_str(&license);
        final_license.push_str("\n--]]\n\n");
        final_license.push_str("script:Destroy()\n");
        final_license.push_str("return error(\"This is a LICENSE file (MIT)\")");
        final_license
    };

    let vluau_source =
        read_to_string("./src/vLuau.luau").expect("Failed to read vLuau.luau");

    let fiu_source = 
        read_to_string("./src/Fiu.luau").expect("Failed to read Fiu.luau");

    let luauception_source =
        read_to_string("./src/LuauCeption.luau").expect("Failed to read LuauCeption.luau");

    let getenv_source =
        read_to_string("./src/getenv.luau").expect("Failed to read getenv.luau");

    let dom = WeakDom::new(
        InstanceBuilder::new("ModuleScript")
            .with_name("vLuau")
            .with_property("Source", vluau_source)
            .with_children([
                module_script_with_source("Fiu", fiu_source),
                module_script_with_source("LuauCeption", luauception_source),
                module_script_with_source("getenv", getenv_source),
                module_script_with_source("LICENSE", license),
            ])
    );

    let file = File::create("vLuau.rbxm").expect("Failed to open vLuau.rbxm");

    to_writer(&file, &dom, &[dom.root_ref()]).expect("Failed to write vLuau.rbxm");

    eprintln!("Successfully created vLuau.rbxm");
}