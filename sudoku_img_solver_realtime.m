%DEPENDENCIAS: MATLAB Support Package for USB Webcams

clear
close all
clc


%PARAMETROS------------------------------------------------------------------------
numImgDim = 320;	%Dimensiones de las imagenes de referencia de los numeros
brilloCamara = 100;
binarizeSens = 0.6;
dimTablero = 9;		%Dimensiones del tablero (ha de ser divisible entre 3)
iWebcam = 1;		%Webcam a usar (para cuando hay varias)
%----------------------------------------------------------------------------------



%Precargar imagenes numeros para correlacion
numberImages = zeros(numImgDim, numImgDim*9);
for j=1:9
		filename = "img_ref/"+j+".png";
		INumber =imread(filename);
		INumber = imbinarize(INumber);
		numberImages(:, j*numImgDim+1:j*numImgDim+numImgDim) = INumber;
end


%Cargar camara
webcams = webcamlist;
cam = webcam(webcams{iWebcam});
cam.Brightness = brilloCamara;

preview = figure('Name', 'Escaneando Tablero', 'ToolBar', 'none', 'MenuBar', 'none', 'WindowState', 'maximized');



prevTablero = zeros(dimTablero);
errorMsg = "";

%Bucle principal
while true
	tablero = zeros(dimTablero);

	%Tomar frame
    FrameOriginal = snapshot(cam);
	I = rgb2gray(FrameOriginal);
	I = imbinarize(I,'adaptive','ForegroundPolarity','dark','Sensitivity',binarizeSens);
	[Iheight, Iwidth] = size(I);
	

   	
	if(ishandle(preview))
		% Mostrar frame
   		imshow(FrameOriginal,'interpolation','bilinear','InitialMagnification','fit');
		title({"Situa el tablero sobre la guía", errorMsg});
   		hold on;
	else
		%Si se cierra la ventana de previsualizacion, terminar
		return;
	end
	

	%Dibujar marco guia
	guiaDim = round(Iheight*0.8);
	guiax1 = round(Iwidth/2)-round(guiaDim/2);
	guiax2 = guiax1 + guiaDim;
	guiaX = [guiax1, guiax2, guiax2, guiax1];
	
	guiay1 = round(Iheight/2)-round(guiaDim/2);
	guiay2 = guiay1+guiaDim;
	guiaY = [guiay1, guiay1, guiay2, guiay2];
	patch(guiaX, guiaY,'green','FaceAlpha',.05,'LineWidth',2);


	%Deteccion de celdas
	imstats = regionprops(I,'BoundingBox');
	boxes = [imstats.BoundingBox]';
	boxes = reshape(boxes, 4, length(boxes)/4)';

	
	%Dejar solo las boxes en un rango de tamaño y que son cuadradas
	areaUmbralMin = round(guiaDim/dimTablero)^2 * 0.7; 
	areaUmbralMax = round(guiaDim/dimTablero)^2 * 1.3; 
	proporcionUmbral = 0.5;
	areas = boxes(:, 3) .* boxes(:, 4);
	proporciones = boxes(:, 3) ./ boxes(:, 4);
	indicesUmbral = find(areas >= areaUmbralMin & areas<=areaUmbralMax & abs(proporciones - 1) <= proporcionUmbral);
	
	areas = areas(indicesUmbral);
	boxes = boxes(indicesUmbral,:);

    %Dejar solo las boxes cercanas a la guia
	iBoxesCercanas = (boxes(:,1) > guiax1-(guiaDim*0.3) & boxes(:,1) < (guiax2+guiaDim*0.3) & boxes(:,2) > guiay1-guiaDim*0.3 & boxes(:,2) < guiay2+guiaDim*0.3);
	newBoxes = boxes(iBoxesCercanas,:);
    areas = areas(iBoxesCercanas);


    %Si no es capaz de encontrar todas celdas, mostrar celdas rojas y pasar al siguiente frame
	if(size(newBoxes, 1) < dimTablero^2)
		boxesCoordsX = [ceil(newBoxes(:,1)) ceil(newBoxes(:,1))+newBoxes(:,3) ceil(newBoxes(:,1))+newBoxes(:,3) ceil(newBoxes(:,1))];
		boxesCoordsY = [ceil(newBoxes(:,2)) ceil(newBoxes(:,2)) ceil(newBoxes(:,2))+newBoxes(:,4) ceil(newBoxes(:,2))+newBoxes(:,4)];
		patch(boxesCoordsX', boxesCoordsY','red','FaceAlpha',.1,'LineWidth',1);
		continue
	elseif(size(newBoxes, 1) > dimTablero^2)
		%Si encuentra mas boxes de la cuenta, buscar el area de box mas frecuente y obtener las dimTablero^2 boxes con area mas cercana a esta
		moda = mode(areas);
		diferencia_absoluta = abs(areas - moda);
		matriz_con_indices = [diferencia_absoluta, (1:size(areas, 1))'];
		matriz_ordenada = sortrows(matriz_con_indices, 1);
		indices_cercanas = matriz_ordenada(1:dimTablero^2, 2);
		
		selectedBoundingBoxes = newBoxes(indices_cercanas, :);
	else
		selectedBoundingBoxes = newBoxes;
	end
	
	

	%Mostrar Celdas Azules
	x1 = selectedBoundingBoxes(:,3); %longitud x boundingbox
	y1 = selectedBoundingBoxes(:,4); %longitud y boundingbox
	
	boxesCoordsX = [ceil(selectedBoundingBoxes(:,1))  ceil(selectedBoundingBoxes(:,1))+x1  ceil(selectedBoundingBoxes(:,1))+x1 ceil(selectedBoundingBoxes(:,1))];
	boxesCoordsY = [ceil(selectedBoundingBoxes(:,2))  ceil(selectedBoundingBoxes(:,2))  ceil(selectedBoundingBoxes(:,2))+y1 ceil(selectedBoundingBoxes(:,2))+y1];
	patch(boxesCoordsX', boxesCoordsY','blue','FaceAlpha',.1,'LineWidth',1);
	patch(boxesCoordsX', boxesCoordsY','blue','FaceAlpha',.1,'LineWidth',1);
		

	%Ordenar las bounding boxes por fila y columna
	sortedSelectedBoundingBoxes = zeros(size(selectedBoundingBoxes));
	for i=0:dimTablero-1
		[~, iaux] = sortrows(selectedBoundingBoxes, 2);
		row = selectedBoundingBoxes(iaux(1:dimTablero), :);
		row = sortrows(row, 1);
		sortedSelectedBoundingBoxes(1+i*dimTablero:(i+1)*dimTablero, :) = row;
		selectedBoundingBoxes(iaux(1:dimTablero), :) = Inf;
	end
	selectedBoundingBoxes = sortedSelectedBoundingBoxes;


	%Procesar las bounding boxes
	for i=1:size(selectedBoundingBoxes,1)

		%Obtenemos el contenido de la bounding box
		crop = imcrop(I, selectedBoundingBoxes(i,:));
		crop = ~imclearborder(~crop);

		%Si la casilla no tiene un numero, pasar al siguiente frame
		[alto, ancho] = size(crop);
		porcentajePixeles = (sum(~crop(:)))/(ancho*alto);
		if(porcentajePixeles < 0.04)
			continue
		end
		
		%Encuadramos el numero dentro de la casilla
		stats2 = regionprops(~crop, 'BoundingBox');
		%Si no se encuentra la el numero, pasar al siguiente frame
		if(isempty(stats2))
			continue
		end
		numberBoundingBox = stats2(1).BoundingBox;
		crop = imcrop(crop, numberBoundingBox(1,:));
        

		%Ajustar la imagen del numero a las dimensiones de las imagenes de
		%referencia
		crop = imresize(crop, [numImgDim,NaN]);
		
		[alto, ancho] = size(crop);
		if(alto > ancho)
			diferencia_dimensiones = alto - ancho;
			pixeles_a_agregar_en_cada_lado = floor(diferencia_dimensiones / 2);
			borde_blanco = ones(alto, pixeles_a_agregar_en_cada_lado);
			if mod(diferencia_dimensiones, 2) == 1
				crop_cuadrado = [borde_blanco, crop, borde_blanco, ones(alto, 1)];
			else
				crop_cuadrado = [borde_blanco, crop, borde_blanco];
			end
			crop = crop_cuadrado;
		elseif(alto < ancho)
			diferencia_dimensiones = ancho - alto;
			tamCorte = floor(diferencia_dimensiones / 2);
			if mod(diferencia_dimensiones, 2) == 1
				crop_cuadrado = crop(:, tamCorte:ancho-tamCorte-2);
			else
				crop_cuadrado = crop(:, tamCorte:ancho-tamCorte-1);
			end
			crop = crop_cuadrado;
		end
		

		%Aplicar dilatacion+erosion
		crop = imclose(crop,strel('square',20));
        
		
		%Encontrar imagen de referencia que mas se asemeje
		correlaciones = zeros(9,1);
		for j=1:9
			INumber =numberImages(:, j*numImgDim+1:j*numImgDim+numImgDim);
			correlaciones(j) = corr2(crop, INumber);
		end
		[~, minumber] = max(correlaciones);
		

		%Agregar numero al tablero
		[i1,i2] = ind2sub([dimTablero,dimTablero], i);
		tablero(i1, i2) = minumber;
	end

	
	%Si el tablero ha cambiado, actualizar solucion
	if(~isequal(prevTablero', tablero))
		solTablero = sudoku_solver(tablero);
		if(isempty(solTablero))
			errorMsg = "Escaneo fallido, pruebe a acomodar mejor el tablero";
		else
			errorMsg = "";
		end
		prevTablero = tablero';
	end
	if(~isempty(solTablero))
		for i=1:dimTablero^2
			%Dibujar solucion
			currentBox = selectedBoundingBoxes(i,:);
			text(currentBox(1)+round(currentBox(3)/2), currentBox(2)+round(currentBox(4)/2), num2str(solTablero(i)), 'FontSize', 25, 'Color', 'green');
		end
	end
end