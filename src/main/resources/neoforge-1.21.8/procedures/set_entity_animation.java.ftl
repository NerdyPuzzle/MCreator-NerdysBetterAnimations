if (${input$entity} instanceof ${generator.map(field$customEntity, "entities")} _ent${cbi}) {
	_ent${cbi}.getEntityData().set(${generator.map(field$customEntity, "entities")}.ANIM, 1000);
	_ent${cbi}.getEntityData().set(${generator.map(field$customEntity, "entities")}.ANIM, ${field$operation}${opt.toInt(input$value)});
}